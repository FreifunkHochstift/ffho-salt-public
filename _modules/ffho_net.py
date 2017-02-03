#!/usr/bin/python

import collections
import re

mac_prefix = "f2"

# VRF configuration map
vrf_info = {
	'vrf_external' : {
		'table' : 1023,
		'fwmark' : [ '0x1', '0x1023' ],
	},
}

#
# Default parameters added to any given bonding interface,
# if not specified at the interface configuration.
default_bond_config = {
	'bond-mode': '802.3ad',
	'bond-min-links': '1',
	'bond-xmit-hash-policy': 'layer3+4'
}


#
# Default parameters added to any given bonding interface,
# if not specified at the interface configuration.
default_bridge_config = {
	'bridge-fd' : '0',
	'bridge-stp' : 'no'
}


#
# Hop penalty to set if none is explicitly specified
# Check if one of these roles is configured for any given node, use first match.
default_hop_penalty_by_role = {
	'bbr'       :  5,
	'bras'      : 50,
	'batman_gw' : 50,
}
batman_role_evaluation_order = [ 'bbr', 'batman_gw', 'bras' ]


#
# Default interface attributes to be added to GRE interface to AS201701 when
# not already present in pillar interface configuration.
GRE_FFRL_attrs = {
	'mode'   : 'gre',
	'method' : 'tunnel',
	'mtu'    : '1400',
	'ttl'    : '64',
}


# The IPv4/IPv6 prefix use for Loopback IPs
loopback_prefix = {
	'v4' : '10.132.255.',
	'v6' : '2a03:2260:2342:ffff::',
}


# The DNS zone base names used for generating zone files from IP address
# configured on nodes interfaces.
DNS_zone_names = {
	'forward' : 'ffho.net',
	'rev_v4'  : [
		'132.10.in-addr.arpa',
		'30.172.in-addr.arpa',
		],
	'rev_v6'  : [
		'2.4.3.2.0.6.2.2.3.0.a.2.ip6.arpa',
	]
}

# MTU configuration
MTU = {
	# The default MTU for any interface which does not have a MTU configured
	# explicitly in the pillar node config or does not get a MTU configured
	# by any means of this SDN stuff here.
	'default' : 1500,

	# A batman underlay device, probably a VXLAN or VLAN interface.
	#
	#   1500
	# +   60	B.A.T.M.A.N. adv header + network coding (activated by default by Debian)
	'batman_underlay_iface' : 1560,

	# VXLAN underlay device, probably a VLAN with $POP or between two BBRs.
	#
	#   1560
	# +   14	Inner Ethernet Frame
	# +    8	VXLAN Header
	# +    8	UDP Header
	# +   20	IPv4 Header
	'vxlan_underlay_iface'  : 1610,
}


################################################################################
#                              Internal functions                              #
#                                                                              #
#       Touching anything below will void any warranty you never had ;)        #
#                                                                              #
################################################################################

sites = None

def _get_site_no (sites_config, site_name):
	global sites

	if sites == None:
		sites = {}
		for site in sites_config:
			if site.startswith ("_"):
				continue

			sites[site] = sites_config[site].get ("site_no", -2)

	return sites.get (site_name, -1)


#
# Generate a MAC address after the format f2:dd:dd:ss:nn:nn where
#  dd:dd	is the hexadecimal reprensentation of the nodes device_id
#    ff:ff	representing the gluon nodes
#
#  ss		is the hexadecimal reprensentation of the site_id the interface is connected to
#
#  nn:nn	is the decimal representation of the network the interface is connected to, with
#    00:00	being the dummy interface
#    00:0f	being the VEth internal side interface
#    00:e0	being an external instance dummy interface
#    00:e1	being an inter-gw-vpn interface
#    00:e4	being an nodes fastd tunnel interface of IPv4 transport
#    00:e6	being an nodes fastd tunnel interface of IPv6 transport
#    00:ef	being an extenral instance VEth interface side
#    02:xx	being a connection to local Vlan 2xx
#    1b:24	being the ibss 2.4GHz bssid
#    1b:05	being the ibss 5GHz bssid
#    xx:xx	being a VXLAN tunnel for site ss, with xx being a the underlay VLAN ID (1xyz, 2xyz)
#    ff:ff	being the gluon next-node interface
def gen_batman_iface_mac (site_no, device_no, network):
	net_type_map = {
		'dummy'   : "00:00",
		'int2ext' : "00:0f",
		'dummy-e' : "00:e0",
		'intergw' : "00:e1",
		'nodes4'  : "00:e4",
		'nodes6'  : "00:e6",
		'ext2int' : "00:ef",
	}

	# Well-known network type?
	if network in net_type_map:
		last = net_type_map[network]
	elif type (network) == int:
		last = re.sub (r'(\d{2})(\d{2})', '\g<1>:\g<2>', "%04d" % network)
	else:
		last = "ee:ee"

	# Convert device_no to hex, format number to 4 digits with leading zeros and : betwwen 2nd and 3rd digit
	device_no_hex = re.sub (r'([0-9a-fA-F]{2})([0-9a-fA-F]{2})', '\g<1>:\g<2>', "%04x" % int (device_no))
	# Format site_no to two digit number with leading zero
	site_no_hex = "%02d" % int (site_no)

	return "%s:%s:%s:%s" % (mac_prefix, device_no_hex, site_no_hex, last)


# Gather B.A.T.M.A.N. related config options for real batman devices (e.g. bat0)
# as well as for batman member interfaces (e.g. eth0.100, fastd ifaces etc.)
def _update_batman_config (node_config, iface, sites_config):
	try:
		node_batman_hop_penalty = int (node_config['batman']['hop-penalty'])
	except KeyError,ValueError:
		node_batman_hop_penalty = None

	iface_config = node_config['ifaces'][iface]
	iface_type = iface_config.get ('type', 'inet')
	batman_config = {}

	for item, value in iface_config.items ():
		if item.startswith ('batman-'):
			batman_config[item] = value
			iface_config.pop (item)

	# B.A.T.M.A.N. device (e.g. bat0)
	if iface_type == 'batman':
		if 'batman-hop-penalty' not in batman_config:
			# If there's a hop penalty set for the node, but not for the interface
			# apply the nodes hop penalty
			if node_batman_hop_penalty:
				batman_config['batman-hop-penalty'] = node_batman_hop_penalty

			# If there's no hop penalty set for the node, use a default hop penalty
			# for the roles the node might have, if any
			else:
				node_roles = node_config.get ('roles', [])
				for role in batman_role_evaluation_order:
					if role in node_roles:
						batman_config['batman-hop-penalty'] = default_hop_penalty_by_role[role]

		# If batman ifaces were specified as a list - which they should -
		# generate a sorted list of interface names as string representation
		if 'batman-ifaces' in batman_config and type (batman_config['batman-ifaces']) == list:
			batman_iface_str = " ".join (sorted (batman_config['batman-ifaces']))
			batman_config['batman-ifaces'] = batman_iface_str

	# B.A.T.M.A.N. member interface (e.g. eth.100, fastd ifaces, etc.)
	elif iface_type == 'batman_iface':
		# Generate unique MAC address for every batman iface, as B.A.T.M.A.N.
		# will get puzzled with multiple interfaces having the same MAC and
		# do nasty things.

		site = iface_config.get ('site')
		site_no = _get_site_no (sites_config, site)
		device_no = node_config.get ('id')

		network = 1234
		# Generate a unique BATMAN-MAC for this interfaces
		match = re.search (r'^vlan(\d+)', iface)
		if match:
			network = int (match.group (1))

		iface_config['hwaddress'] = gen_batman_iface_mac (site_no, device_no, network)

	iface_config['batman'] = batman_config


# Mangle bond specific config items with default values and store them in
# separate sub-dict for easier access and configuration.
def _update_bond_config (config):
	bond_config = default_bond_config.copy ()

	for item, value in config.items ():
		if item.startswith ('bond-'):
			bond_config[item] = value
			config.pop (item)

	if bond_config['bond-mode'] not in ['2', 'balance-xor', '4', '802.3ad']:
		bond_config.pop ('bond-xmit-hash-policy')

	config['bond'] = bond_config


# Mangle bridge specific config items with default values and store them in
# separate sub-dict for easier access and configuration.
def _update_bridge_config (config):
	bridge_config = default_bridge_config.copy ()

	for item, value in config.items ():
		if item.startswith ('bridge-'):
			bridge_config[item] = value
			config.pop (item)

		# Fix and salt mangled string interpretation back to real string.
		if type (value) == bool:
			bridge_config[item] = "yes" if value else "no"

	# If bridge ports were specified as a list - which they should -
	# generate a sorted list of interface names as string representation
	if 'bridge-ports' in bridge_config and type (bridge_config['bridge-ports']) == list:
		bridge_ports_str = " ".join (sorted (bridge_config['bridge-ports']))
		bridge_config['bridge-ports'] = bridge_ports_str

	config['bridge'] = bridge_config


# Move vlan specific config items into a sub-dict for easier access and pretty-printing
# in the configuration file
def _update_vlan_config (config):
	vlan_config = {}

	for item, value in config.items ():
		if item.startswith ('vlan-'):
			vlan_config[item] = value
			config.pop (item)

	config['vlan'] = vlan_config


# Pimp Veth interfaces
# * Add peer interface name IF not present
# * Add link-type veth IF not present
def _update_veth_config (interface, config):
	veth_peer_name = {
		'veth_ext2int' : 'veth_int2ext',
		'veth_int2ext' : 'veth_ext2int'
	}

	if interface not in veth_peer_name:
		return

	if 'link-type' not in config:
		config['link-type'] = 'veth'

	if 'veth-peer-name' not in config:
		config['veth-peer-name'] = veth_peer_name[interface]


# Generate configuration entries for any batman related interfaces not
# configured explicitly, but asked for implicitly by role batman and a
# (list of) site(s) specified in the node config.
def _generate_batman_interface_config (node_config, ifaces, sites_config):
	# No role 'batman', nothing to do
	roles = node_config.get ('roles', [])
	if 'batman' not in roles:
		return

	# Should there be a 2nd external BATMAN instance?
	batman_ext = 'batman_ext' in roles or 'bras' in roles

	device_no = node_config.get ('id', -1)

	for site in node_config.get ('sites', []):
		site_no = _get_site_no (sites_config, site)

		# Predefine interface names for regular/external BATMAN instance
		# and possible VEth link pair for connecting both instances.
		bat_site_if = "bat-%s" % site
		dummy_site_if = "dummy-%s" % site
		bat_site_if_ext = "bat-%s-ext" % site
		dummy_site_if_ext = "dummy-%s-e" % site
		int2ext_site_if = "i2e-%s" % site
		ext2int_site_if = "e2i-%s" % site

		site_ifaces = {
			# Regular BATMAN interface, always present
			bat_site_if : {
				'type' : 'batman',
				# int2ext_site_if will be added automagically if requred
				'batman-ifaces' : [ dummy_site_if ],
				'batman-ifaces-ignore-regex': '.*_.*',
			},

			# Dummy interface always present in regular BATMAN instance
			dummy_site_if : {
				'link-type' : 'dummy',
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, 'dummy'),
				'mtu'       : MTU['batman_underlay_iface'],
			},

			# Optional 2nd "external" BATMAN instance
			bat_site_if_ext : {
				'type' : 'batman',
				'batman-ifaces' : [ dummy_site_if_ext, ext2int_site_if ],
				'batman-ifaces-ignore-regex': '.*_.*',
				'ext_only' : True,
			},

			# Optional dummy interface always present in 2nd "external" BATMAN instance
			dummy_site_if_ext : {
				'link-type' : 'dummy',
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, 'dummy-e'),
				'ext_only' : True,
				'mtu'       : MTU['batman_underlay_iface'],
			},

			# Optional VEth interface pair - internal side
			int2ext_site_if : {
				'link-type' : 'veth',
				'veth-peer-name' : ext2int_site_if,
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, 'int2ext'),
				'ext_only' : True,
			},

			# Optional VEth interface pair - "external" side
			ext2int_site_if : {
				'link-type' : 'veth',
				'veth-peer-name' : int2ext_site_if,
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, 'ext2int'),
				'ext_only' : True,
			},
		}


		for iface, iface_config_tmpl in site_ifaces.items ():
			# Ignore any interface only relevant when role batman_ext is set
			# but it isn't
			if not batman_ext and iface_config_tmpl.get ('ext_only', False):
				continue

			# Remove ext_only key so we don't leak it into ifaces dict
			if 'ext_only' in iface_config_tmpl:
				del iface_config_tmpl['ext_only']

			# If there is no trace of the desired iface config yet...
			if iface not in ifaces:
				# ... just place our template there.
				ifaces[iface] = iface_config_tmpl

				# If there should be an 2nd external BATMAN instance make sure
				# the internal side of the VEth iface pair is connected to the
				# internal BATMAN instance.
				if batman_ext and iface == bat_site_if:
					iface_config_tmpl['batman-ifaces'].append (int2ext_site_if)

			# If there already is an interface configuration try to enhance it with
			# meaningful values from our template and force correct hwaddress to be
			# used.
			else:
				iface_config = ifaces[iface]

				# Force hwaddress to be what we expect.
				if 'hwaddress' in iface_config_tmpl:
					iface_config['hwaddress'] = iface_config_tmpl['hwaddress']

				# Copy every attribute of the config template missing in iface config
				for attr in iface_config_tmpl:
					if attr not in iface_config:
						iface_config[attr] = iface_config_tmpl[attr]


	# Make sure there is a bridge present for every site where a mesh_breakout
	# interface should be configured.
	for iface, config in ifaces.items ():
		iface_type = config.get ('type', 'inet')
		if iface_type not in ['mesh_breakout', 'batman_iface']:
			continue

		site = config.get ('site')
		site_bridge = "br-%s" % site
		batman_site_if = "bat-%s" % site

		if iface_type == 'mesh_breakout':
			# If the bridge has already been defined (with an IP maybe) make
			# sure that the corresbonding batman device is part of the bridge-
			# ports.
			if site_bridge in ifaces:
				bridge_config = ifaces.get (site_bridge)

				# If there already is/are (a) bridge-port(s) defined, add
				# the batman and the breakout interfaces if not present...
				bridge_ports = bridge_config.get ('bridge-ports', None)
				if bridge_ports:
					for dev in (batman_site_if, iface):
						if not dev in bridge_ports:
							if type (bridge_ports) == list:
								bridge_ports.append (dev)
							else:
								bridge_config['bridge-ports'] += ' ' + dev

				# ...if there is no bridge-port defined yet, just used
				# the batman and breakout iface.
				else:
					bridge_config['bridge-ports'] = [ iface, batman_site_if ]

			# If the bridge isn't present alltogether, add it.
			else:
				ifaces[site_bridge] = {
					'bridge-ports' : [ iface, batman_site_if ],
				}

		elif iface_type == 'batman_iface':
			batman_ifaces = ifaces[bat_site_if]['batman-ifaces']
			if iface not in batman_ifaces:
				if type (batman_ifaces) == list:
					batman_ifaces.append (iface)
				else:
					batman_ifaces += ' ' + iface


#
# Generate any implicitly defined VXLAN interfaces defined in the nodes iface
# defined in pillar.
# The keyword "batman_connect_sites" on an interface will trigger the
# generation of a VXLAN overlay interfaces.
def _generate_vxlan_interface_config (node_config, ifaces, sites_config):
	# No role 'batman', nothing to do
	if 'batman' not in node_config.get ('roles', []):
		return

	# Sites configured on this node. Nothing to do, if none.
	my_sites = node_config.get ('sites', [])
	if len (my_sites) == 0:
		return

	# As we're still here we can now safely assume that a B.A.T.M.A.N.
	# device has been configured for every site specified in sites list.

	device_no = node_config.get ('id', -1)

	for iface, iface_config in ifaces.items ():
		batman_connect_sites = iface_config.get ('batman_connect_sites', [])

		# If we got a string, convert it to a list with a single element
		if type (batman_connect_sites) == str:
			batman_connect_sites = [ batman_connect_sites ]

		# If there the list of sites to connect is empty, there's nothing to do here.
		if len (batman_connect_sites) == 0:
			continue

		# Set the MTU of this (probably) VLAN device to the MTU required for a VXLAN underlay
		# device, where B.A.T.M.A.N. adv. is to be expected within the VXLAN overlay.
		if 'mtu' not in iface_config:
			iface_config['mtu'] = MTU['vxlan_underlay_iface']

			# If this is a VLAN - which it probably is - fix the MTU of the underlying interface, too.
			if 'vlan-raw-device' in iface_config:
				vlan_raw_device = iface_config['vlan-raw-device']
				vlan_raw_device_config = ifaces.get (vlan_raw_device, None)

				# vlan-raw-device might point to ethX which usually isn't configured explicitly
				# as ifupdown2 simply will bring it up anyway by itself. To set the MTU of such
				# an interface we have to add a configuration stanza for it here.
				if vlan_raw_device_config == None:
					vlan_raw_device_config = {}
					ifaces[vlan_raw_device] = vlan_raw_device_config

				if not 'mtu' in vlan_raw_device:
					vlan_raw_device_config['mtu'] = MTU['vxlan_underlay_iface']

		# If the string 'all' is part of the list, blindly use all sites configured for this node
		if 'all' in batman_connect_sites:
			batman_connect_sites = my_sites

		for site in batman_connect_sites:
			# Silenty ignore sites not configured on this node
			if site not in my_sites:
				continue

			# iface_name := vx_<last 5 chars of underlay iface>_<site> stripped to 15 chars
			vx_iface = ("vx_%s_%s" % (re.sub ('vlan', 'v', iface)[-5:], re.sub (r'[_-]', '', site)))[:15]
			site_no = _get_site_no (sites_config, site)
			vni = 100 + site_no
			bat_iface = "bat-%s" % site

			try:
				iface_id = int (re.sub ('vlan', '', iface))

				# Gather interface specific mcast address.
				# The address is derived from the vlan-id of the underlying interface,
				# assuming that it in fact is a vlan interface.
				# Mangle the vlan-id into two 2 digit values, eliminating any leading zeros.
				iface_id_4digit = "%04d" % iface_id
				octet2 = int (iface_id_4digit[0:2])
				octet3 = int (iface_id_4digit[2:4])
				mcast_ip = "225.%s.%s.%s" % (octet2, octet3, site_no)

				vni = octet2 * 256 * 256 + octet3 * 256 + site_no
			except ValueError:
				iface_id = 9999
				mcast_ip = "225.0.0.%s" % site_no
				vni = site_no

			# bail out if VXLAN tunnel already configured
			if vx_iface in ifaces:
				continue

			# If there's no batman interface for this site, there's no point
			# in setting up a VXLAN interfaces
			if bat_iface not in ifaces:
				continue

			# Add the VXLAN interface
			ifaces[vx_iface] = {
				'vxlan' : {
					'vxlan-id'        : vni,
					'vxlan-svcnodeip' : mcast_ip,
					'vxlan-physdev'   : iface,
				},
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, iface_id),
				'mtu'       : MTU['batman_underlay_iface'],
			}

			# If the batman interface for this site doesn't have any interfaces
			# set up - which basicly cannot happen - add this VXLAN tunnel as
			# the first in the list.
			if not 'batman-ifaces' in ifaces[bat_iface]:
				ifaces[bat_iface]['batman-ifaces'] = [ vx_iface ]
				continue

			# In the hope there already are interfaces for batman set up already
			# add this VXLAN tunnel to the list
			batman_ifaces = ifaces[bat_iface]['batman-ifaces']
			if vx_iface not in batman_ifaces:
				if type (batman_ifaces) == list:
					batman_ifaces.append (vx_iface)
				else:
					batman_ifaces += ' ' + vx_iface


#
# Generate implicitly defined VRFs according to the vrf_info dict at the top
# of this file
def _generate_vrfs (ifaces):
	for iface, iface_config in ifaces.items ():
		vrf = iface_config.get ('vrf', None)
		if vrf and vrf not in ifaces:
			conf = vrf_info.get (vrf, {})
			table = conf.get ('table', 1234)
			fwmark = conf.get ('fwmark', None)

			ifaces[vrf] = {
				'vrf-table' : table,
			}

			# Create ip rule's for any fwmarks defined
			if fwmark:
				up = []

				# Make sure we are dealing with a list even if there is only one mark to be set up
				if type (fwmark) in (str, int):
					fwmark = [ fwmark ]

				# Create ip rule entries for IPv4 and IPv6 for every fwmark
				for mark in fwmark:
					up.append ("ip    rule add fwmark %s table %s" % (mark, table))
					up.append ("ip -6 rule add fwmark %s table %s" % (mark, table))

				ifaces[vrf]['up'] = up


def _generate_ffrl_gre_tunnels (ifaces):
	for iface, iface_config in ifaces.items ():
		# We only care for GRE_FFRL type interfaces
		if iface_config.get ('type', '') != 'GRE_FFRL':
			continue

		# Copy default values to interface config
		for attr, val in GRE_FFRL_attrs.items ():
			if not attr in iface_config:
				iface_config[attr] = val

		# Guesstimate local IPv4 tunnel endpoint address from tunnel-physdev
		if not 'local' in iface_config and 'tunnel-physdev' in iface_config:
			try:
				physdev_prefixes = [p.split ('/')[0] for p in ifaces[iface_config['tunnel-physdev']]['prefixes'] if '.' in p]
				if len (physdev_prefixes) == 1:
					iface_config['local'] = physdev_prefixes[0]
			except KeyError:
				pass

def _generate_loopback_ips (ifaces, node_config, node_id):
	v4_ip = "%s/32"  % get_loopback_ip (node_config, node_id, 'v4')
	v6_ip = "%s/128" % get_loopback_ip (node_config, node_id, 'v6')

	# Interface lo already present?
	if 'lo' not in ifaces:
		ifaces['lo'] = { 'prefixes' : [] }

	# Add 'prefixes' list if not present
	if 'prefixes' not in ifaces['lo']:
		ifaces['lo']['prefixes'] = []

	prefixes = ifaces['lo']['prefixes']
	if v4_ip not in prefixes:
		prefixes.append (v4_ip)

	if v6_ip not in prefixes:
		prefixes.append (v6_ip)


################################################################################
#                              Public functions                                #
################################################################################

# Generate network interface configuration for given node.
#
# This function will read the network configuration from pillar and will
#  * enhance it with all default values configured at the top this file
#  * auto generate any implicitly configured
#   * VRFs
#   * B.A.T.M.A.N. instances and interfaces
#   * VXLAN interfaces to connect B.A.T.M.A.N. sites
#   * Loopback IPs derived from numeric node ID
#
# @param: node_config	Pillar node configuration (as dict)
# @param: sites_config	Pillar sites configuration (as dict)
# @param: node_id	Minion name / Pillar node configuration key
def get_interface_config (node_config, sites_config, node_id = ""):
	# Get config of this node and dict of all configured ifaces
	ifaces = node_config.get ('ifaces', {})

	# Generate configuration entries for any batman related interfaces not
	# configured explicitly, but asked for implicitly by role <batman> and
	# a (list of) site(s) specified in the node config.
	_generate_batman_interface_config (node_config, ifaces, sites_config)

	# Generate VXLAN tunnels for every interfaces specifying 'batman_connect_sites'
	_generate_vxlan_interface_config (node_config, ifaces, sites_config)

	# Enhance ifaces configuration with some meaningful defaults for
	# bonding, bridge and vlan interfaces, MAC address for batman ifaces, etc.
	for interface, config in ifaces.items ():
		if type (config) not in [ dict, collections.OrderedDict ]:
			raise Exception ("Configuration for interface %s on node %s seems broken!" % (interface, node_id))

		iface_type = config.get ('type', 'inet')

		if 'batman-ifaces' in config or iface_type.startswith ('batman'):
			_update_batman_config (node_config, interface, sites_config)

		if 'bond-slaves' in config:
			_update_bond_config (config)

		# FIXME: This maybe will not match on bridges without any member ports configured!
		if 'bridge-ports' in config or interface.startswith ('br-'):
			_update_bridge_config (config)

		if 'vlan-raw-device' in config or 'vlan-id' in config:
			_update_vlan_config (config)

		# Pimp configuration for VEth link pairs
		if interface.startswith ('veth_'):
			_update_veth_config (interface, config)

	# Auto generate Loopback IPs IFF not present
	_generate_loopback_ips (ifaces, node_config, node_id)

	# Auto generated VRF devices for any VRF found in ifaces and not already configured.
	_generate_vrfs (ifaces)

	# Pimp GRE_FFRL type inteface configuration with default values
	_generate_ffrl_gre_tunnels (ifaces)

	# Drop any config parameters used in node interface configuration not
	# relevant anymore for config file generation.
	for interface, config in ifaces.items ():
		# Set default MTU if not already set manually or by any earlier function
		if interface != 'lo' and 'mtu' not in config:
			config['mtu'] = MTU['default']

		for key in [ 'batman_connect_sites', 'ospf', 'site', 'type' ]:
			if key in config:
				config.pop (key)
	# This leaves 'auto', 'prefixes' and 'desc' as keys which should not be directly
	# printed into the remaining configuration. These are handled within the jinja
	# interface template.

	return ifaces


# Generate entries for /etc/bat-hosts for every batman interface we will configure on any node.
# For readability purposes superflous/redundant information is being stripped/supressed.
# As these names will only show up in batctl calls with a specific site, site_names in interfaces
# are stripped. Dummy interfaces are stripped as well.
def gen_bat_hosts (nodes_config, sites_config):
	bat_hosts = {}

	for node_id in sorted (nodes_config.keys ()):
		node_config = nodes_config.get (node_id)
		node_name = node_id.split ('.')[0]

		ifaces = get_interface_config (node_config, sites_config, node_id)
		for iface in sorted (ifaces):
			iface_config = ifaces.get (iface)

			hwaddress = iface_config.get ('hwaddress', None)
			if hwaddress == None:
				continue

			entry_name = node_name
			match = re.search (r'^dummy-(.+)(-e)?$', iface)
			if match:
				if match.group (2):
					entry_name += "-e"

				# Append site to make name unique
				entry_name += "/%s" % match.group (1)
			else:
				entry_name += "/%s" % re.sub (r'^(vx_.*|i2e|e2i)[_-](.*)$', '\g<1>/\g<2>', iface)


			bat_hosts[hwaddress] = entry_name

		if 'fastd' in node_config.get ('roles', []):
			device_no = node_config.get ('id')
			for site in node_config.get ('sites', []):
				site_no = _get_site_no (sites_config, site)

				for network in ('intergw', 'nodes4', 'nodes6'):
					hwaddress = gen_batman_iface_mac (site_no, device_no, network)
					bat_hosts[hwaddress] = "%s/%s/%s" % (node_name, network, site)

	return bat_hosts


# Generate eBGP session parameters for FFRL Transit from nodes pillar information.
def get_ffrl_bgp_config (ifaces, proto):
	from ipcalc import IP

	_generate_ffrl_gre_tunnels (ifaces)

	sessions = {}

	for iface in sorted (ifaces):
		# We only care for GRE tunnels to the FFRL Backbone
		if not iface.startswith ('gre_ffrl_'):
			continue

		iface_config = ifaces.get (iface)

		# Search for IPv4/IPv6 prefix as defined by proto parameter
		local = None
		neighbor = None
		for prefix in iface_config.get ('prefixes', []):
			if (proto == 'v4' and '.' in prefix) or (proto == 'v6' and ':' in prefix):
				local = prefix.split ('/')[0]

				# Calculate neighbor IP as <local IP> - 1
				if proto == 'v4':
					neighbor = str (IP (int (IP (local)) - 1, version = 4))
				else:
					neighbor = str (IP (int (IP (local)) - 1, version = 6))

				break

		# Strip gre_ prefix iface name and use it as identifier for the eBGP session.
		name = re.sub ('gre_ffrl_', 'ffrl_', iface)

		sessions[name] = {
			'local' : local,
			'neighbor' : neighbor,
			'bgp_local_pref' : iface_config.get ('bgp_local_pref', None),
		}

	return sessions


# Get list of IP address configured on given interface on given node.
#
# @param: node_config	Pillar node configuration (as dict)
# @param: iface_name	Name of the interface defined in pillar node config
# 			OR name of VRF ("vrf_<something>") whichs ifaces are
#			to be examined.
def get_node_iface_ips (node_config, iface_name):
	ips = {
		'v4' : [],
		'v6' : [],
	}


	ifaces = node_config.get ('ifaces', {})
	ifaces_names = [ iface_name ]

	if iface_name.startswith ('vrf_'):
		# Reset list of ifaces_names to consider
		ifaces_names = []
		vrf = iface_name

		for iface, iface_config in ifaces.items ():
			# Ignore any iface NOT in the given VRF
			if iface_config.get ('vrf', None) != vrf:
				continue

			# Ignore any VEth pairs
			if iface.startswith ('veth'):
				continue

			ifaces_names.append (iface)

	try:
		for iface in ifaces_names:
			for prefix in ifaces[iface]['prefixes']:
				ip_ver = 'v6' if ':' in prefix else 'v4'

				ips[ip_ver].append (prefix.split ('/')[0])
	except KeyError:
		pass

	return ips


#
# Get the lookback IP of the given node for the given proto
#
# @param node_config:	Pillar node configuration (as dict)
# @param node_id:	Minion name / Pillar node configuration key
# @param proto:		{ 'v4', 'v6' }
def get_loopback_ip (node_config, node_id, proto):
	if proto not in [ 'v4', 'v6' ]:
		raise Exception ("get_loopback_ip(): Invalid proto: \"%s\"." % proto)

	if not proto in loopback_prefix:
		raise Exception ("get_loopback_ip(): No loopback_prefix configured for IP%s in ffno_net module!" % proto)

	if not 'id' in node_config:
		raise Exception ("get_loopback_ip(): No 'id' configured in pillar for node \"%s\"!" % node_id)

	# Every rule has an exception.
	# If there is a loopback_overwrite configuration for this node, use this instead of
	# the generated IPs.
	if 'loopback_override' in node_config:
		if proto not in node_config['loopback_override']:
			raise Exception ("get_loopback_ip(): No loopback_prefix configured for IP%s in node config / loopback_override!" % proto)

		return node_config['loopback_override'][proto]

	return "%s%s" % (loopback_prefix.get (proto), node_config.get ('id'))


#
# Get the router id (read: IPv4 Lo-IP) out of the given node config.
def get_router_id (node_config, node_id):
	return get_loopback_ip (node_config, node_id, 'v4')



# Compute minions OSPF interface configuration according to FFHO routing policy
# See https://wiki.ffho.net/infrastruktur:vlans for information about Vlans
def get_ospf_interface_config (node_config, grains_id):
	ospf_node_config = node_config.get ('ospf', {})

	ospf_interfaces = {}

	for iface, iface_config in node_config.get ('ifaces', {}).items ():
		# By default we don't speak OSPF on interfaces
		ospf_on = False

		# Defaults for OSPF interfaces
		ospf_config = {
			'stub' : True,			# Active/Passive interface
			'cost' : 12345,
			# 'type' 			# Area type
		}

		# OSPF configuration for interface given?
		ospf_config_pillar = iface_config.get ('ospf', {})

		# Local Gigabit Ethernet based connections (PTP or L2 subnets), cost 10
		if re.search (r'^(br-?|br\d+\.|vlan)10\d\d$', iface):
			ospf_on = True
			ospf_config['stub'] = False
			ospf_config['cost'] = 10
			ospf_config['desc'] = "Wired Gigabit connection"

		# AF-X based WBBL connection
		elif re.search (r'^vlan20\d\d$', iface):
			ospf_on = True
			ospf_config['stub'] = False
			ospf_config['cost'] = 100
			ospf_config['desc'] = "AF-X based WBBL connection"

		# Non-AF-X based WBBL connection
		elif re.search (r'^vlan22\d\d$', iface):
			ospf_on = True
			ospf_config['stub'] = False
			ospf_config['cost'] = 1000
			ospf_config['desc'] = "Non-AF-X based WBBL connection"

		# Management Vlans
		elif re.search (r'^vlan30\d\d$', iface):
			ospf_on = True
			ospf_config['stub'] = True
			ospf_config['cost'] = 10

		# Active OSPF on OpenVPN tunnels, cost 10000
		elif iface.startswith ('ovpn-'):
			ospf_on = True
			ospf_config['stub'] = False
			ospf_config['cost'] = 10000

			# Inter-Core links should have cost 5000
			if iface.startswith ('ovpn-cr') and grains_id.startswith ('cr'):
				ospf_config['cost'] = 5000

			# OpenVPN tunnels to EdgeRouters
			elif iface.startswith ('ovpn-er-'):
				ospf_config['type'] = 'broadcast'

		# Configure Out-of-band OpenVPN tunnels as stub interfaces,
		# so recursive next-hop lookups for OOB-BGP-session will work.
		elif iface.startswith ('oob-'):
			ospf_on = True
			ospf_config['stub'] = True
			ospf_config['cost'] = 1000

		# OSPF explicitly enabled for interface
		elif 'ospf' in iface_config:
			ospf_on = True
			# iface ospf parameters will be applied later


		# Go on if OSPF should not be actived
		if not ospf_on:
			continue

		# Explicit OSPF interface configuration parameters take precendence over generated ones
		for attr, val in ospf_config_pillar:
			ospf_config[attr] = val

		# Convert boolean values to 'yes' / 'no' string values
		for attr, val in ospf_config.items ():
			if type (val) == bool:
				ospf_config[attr] = 'yes' if val else 'no'

		# Store interface configuration
		ospf_interfaces[iface] = ospf_config

	return ospf_interfaces


# Return (possibly empty) subset of Traffic Engineering entries from 'te' pillar entry
# relevenant for this minion and protocol (IPv4 / IPv6)
def get_te_prefixes (te_node_config, grains_id, proto):
	te_config = {}

	for prefix, prefix_config in te_node_config.get ('prefixes', {}).items ():
		prefix_proto = 'v6' if ':' in prefix else 'v4'

		# Should this TE policy be applied on this node and is the prefix
		# of the proto we are looking for?
		if grains_id in prefix_config.get ('nodes', []) and prefix_proto == proto:
			te_config[prefix] = prefix_config

	return te_config



def generate_DNS_entries (nodes_config, sites_config):
	import ipaddress

	forward_zone_name = ""
	forward_zone = []
	zones = {
		# <forward_zone_name>: [],
		# <rev_zone1_name>: [],
		# <rev_zone2_name>: [],
		# ...
	}

	# Fill zones dict with zones configured in DNS_zone_names at the top of this file.
	# Make sure the zone base names provided start with a leading . so the string
	# operations later can be done easily and safely. Proceed with fingers crossed.
	for entry, value in DNS_zone_names.items ():
		if entry == "forward":
			zone = value
			if not zone.startswith ('.'):
				zone = ".%s" % zone

			zones[zone] = forward_zone
			forward_zone_name = zone

		if entry in [ 'rev_v4', 'rev_v6' ]:
			for zone in value:
				if not zone.startswith ('.'):
					zone = ".%s" % zone

				zones[zone] = []


	# Process all interfaace of all nodes defined in pillar and generate forward
	# and reverse entries for all zones defined in DNS_zone_names. Automagically
	# put reverse entries into correct zone.
	for node_id in sorted (nodes_config):
		node_config = nodes_config.get (node_id)
		ifaces = get_interface_config (node_config, sites_config, node_id)

		for iface in sorted (ifaces):
			iface_config = ifaces.get (iface)

			# We only care for interfaces with IPs configured
			prefixes = iface_config.get ("prefixes", None)
			if prefixes == None:
				continue

			# Ignore any interface in $VRF
			if iface_config.get ('vrf', "") in [ 'vrf_external' ]:
				continue

			for prefix in sorted (prefixes):
				ip = ipaddress.ip_address (u'%s' % prefix.split ('/')[0])
				proto = 'v%s' % ip.version

				# The entry name is
				#             <node_id>         when interface 'lo'
				# <node_name>.srv.<residual>    when interface 'srv' (or magically detected internal srv record)
				# <interface>.<node_id>         else
				entry_name = node_id
				if iface != "lo":
					entry_name = "%s.%s" % (iface, node_id)

				elif iface == 'srv' or re.search (r'^(10.132.251|2a03:2260:2342:f251:)', prefix):
					entry_name = re.sub (r'^([^.]+)\.(.+)$', r'\g<1>.srv.\g<2>', entry_name)


				# Strip forward zone name from entry_name and store forward entry
				# with correct entry type for found IP address.
				forward_entry_name = re.sub (forward_zone_name, "", entry_name)
				forward_entry_name = re.sub (forward_zone_name, "", entry_name)
				forward_entry_typ = "A" if ip.version == 4 else "AAAA"
				forward_zone.append		("%s		IN %s	%s" % (forward_entry_name, forward_entry_typ, ip))

				# Find correct reverse zone, if configured and strip reverse zone name
				# from calculated reverse pointer name. Store reverse entry if we found
				# a zone for it. If no configured reverse zone did match, this reverse
				# entry will be ignored.
				for zone in zones:
					if ip.reverse_pointer.find (zone) > 0:
						PTR_entry = re.sub (zone, "", ip.reverse_pointer)
						zones[zone].append ("%s		IN PTR	%s." % (PTR_entry, entry_name))

						break

	return zones

#!/usr/bin/python

import re

mac_prefix = "f2"

vrf_info = {
	'vrf_external' : {
		'table' : 1023,
		'fwmark' : [ '0x1', '0x1023' ],
	},
}


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
#    ff:ff	being the gluon next-node interface
#    xx:xx	being a VXLAN tunnel for site ss, with xx being a the underlay VLAN ID (1xyz, 2xyz)
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


#
# Default parameters added to any given bonding/bridge interface,
# if not specified at the interface configuration.
default_bond_config = {
	'bond-mode': '802.3ad',
	'bond-min-links': '1',
	'bond-xmit-hash-policy': 'layer3+4'
}

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


## Generate VXLAN tunnels for every configured batman peer for every site
## configured on this and the peer node.
#def _generate_vxlan_interface_config_complex (node_config, ifaces, node_id, nodes_config):
#	# No role 'batman', nothing to do
#	if 'batman' not in node_config.get ('roles', []):
#		return
#
#	# No batman peers configred, nothing to do
#	try:
#		peers = node_config['batman']['peers']
#		if type (peers) != list:
#			return
#	except KeyError:
#		return
#
#	# Sites configured on this node. Nothing to do, if none.
#	my_sites = node_config.get ('sites', [])
#	if len (my_sites) == 0:
#		return
#
#	device_no = node_config.get ('id', -1)
#
#	# ...
#	for peer in peers:
#		try:
#			# Try to get node config of peer
#			peer_config = nodes_config.get (peer)
#
#			# Not a batman node?
#			if not 'batman' in peer_config['roles']:
#				continue
#
#			# Verify we are in peers list of peer
#			peers_of_peer = peer_config['batman']['peers']
#			if type (peers_of_peer) != list:
#				continue
#			if node_id not in peers_of_peer:
#				continue
#
#			# Get sites configured on peers
#			sites_of_peer = peer_config.get ('sites')
#		except KeyError:
#			continue
#
#		for site in my_sites:
#			if site not in sites_of_peer:
#				continue
#
#			# Build tunnel here

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

		# If the string 'all' is part of the list, blindly use all sites configured for this node
		if 'all' in batman_connect_sites:
			batman_connect_sites = my_sites

		for site in batman_connect_sites:
			# Silenty ignore sites not configured on this node
			if site not in my_sites:
				continue

			# iface_name := vx_<last 5 chars of underlay iface>_<site> stripped to 15 chars
			vx_iface = "vx_%s_%s" % (re.sub ('vlan', 'v', iface)[-5:], site)[:15]
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
				'hwaddress'       : gen_batman_iface_mac (site_no, device_no, iface_id),
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


GRE_FFRL_attrs = {
	'mode'   : 'gre',
	'method' : 'tunnel',
	'mtu'    : '1400',
	'ttl'    : '64',
}


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


def get_interface_config (node_config, sites_config):
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

	# Auto generated VRF devices for any VRF found in ifaces and not already configured.
	_generate_vrfs (ifaces)

	# Pimp GRE_FFRL type inteface configuration with default values
	_generate_ffrl_gre_tunnels (ifaces)

	# Drop any config parameters used in node interface configuration not
	# relevant anymore for config file generation.
	for interface, config in ifaces.items ():
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

		ifaces = get_interface_config (node_config, sites_config)
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

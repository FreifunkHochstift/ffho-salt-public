#!/usr/bin/python

import collections
from functools import cmp_to_key
import ipaddress
import re
from copy import deepcopy

import ffho

mac_prefix = "f2"

# VRF configuration map
vrf_info = {
	'vrf_external' : {
		'table' : 1023,
		'fwmark' : [ '0x1', '0x1023' ],
	},
	'vrf_mgmt' : {
		'table' : 1042,
	},

	# Out of band management
	'vrf_oobm' : {
		'table' : 1100,
	},
	# Out of band mangement - external uplink
	'vrf_oobm_ext' : {
		'table' : 1101,
		'fwmark' : [ '0x1101' ],
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
# Default parameters added to any given bridge interface,
# if not specified at the interface configuration.
default_bridge_config = {
	'bridge-fd' : '0',
	'bridge-stp' : 'no',
	'bridge-ports-condone-regex' : '^[a-zA-Z0-9]+_(v[0-9]{1,4}|eth[0-9])$',
}


#
# Hop penalty to be set if none is explicitly specified.
# Check if one of these roles is configured for any given node, use first match.
default_hop_penalty_by_role = {
	'bbr'       :  5,
	'bras'      : 50,
	'batman_gw' : 50,
	'batman_ext': 50,
}
batman_role_evaluation_order = [ 'bbr', 'batman_gw', 'bras' ]

# By default we do not set any penalty on an interface and rely on the
# regular hop penalty to do the right thing.  We only want set another
# penalty, if there are additional paths and we want to influnce which
# path is being taken.  One example are routers which have a wifi link
# to the local backbone as well as a VPN link to a gateway, or a fiber
# link plus a wifi backup link.
default_batman_iface_penalty_by_role = {
	'default'     :   0,
	'DCI'         :   5,
	'WBBL'        :  10,
	'WBBL_backup' :  15,
	'VPN_intergw' :  80,
	'VPN_node'    : 100,
}

#
# Default interface attributes to be added to GRE interface to AS201701 when
# not already present in pillar interface configuration.
GRE_FFRL_attrs = {
	'mode'   : 'gre',
	'method' : 'tunnel',
	'mtu'    : '1400',
	'ttl'    : '64',
}


# The IPv4/IPv6 prefix used for Loopback IPs
loopback_prefix = {
	'v4' : '10.132.255.',
	'v6' : '2a03:2260:2342:ffff::',
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

	# VXLAN underlay device, probably a VLAN within $POP or between two BBRs.
	#
	#   1560
	# +   14	Inner Ethernet Frame
	# +    8	VXLAN Header
	# +    8	UDP Header
	# +   20	IPv4 Header
	'vxlan_underlay_iface'  : 1610,

	# VXLAN underlay device, probably a VLAN within $POP or between two BBRs.
	#
	#   1560
	# +   14	Inner Ethernet Frame
	# +    8	VXLAN Header
	# +    8	UDP Header
	# +   40	IPv6 Header
	'vxlan_underlay_iface_ipv6'  : 1630,
}


################################################################################
#                                                                              #
#                       Internal data types and functions                      #
#                                                                              #
#       Touching anything below will void any warranty you never had ;)        #
#                                                                              #
################################################################################


################################################################################
#                                 Data types                                   #
################################################################################

class Prefix (object):
	"""An internet address with a prefix length.

	The given address is expected to be of format ip/plen in CIDR notation.
	The IP as well as the prefix length and address family will be stored
	in attributes.

	.. code-block:: pycon
        >>> a = Prefix ('10.132.23.42/24')
        >>> str (a.ip)
        '10.132.23.42'
        >>> str (a.af)
        '4'
        >>> str (a.plen)
        '24'
        >>> str (a.netmask)
        '255.255.255.0'
        >>> str (a.network_address)
        '10.132.23.0'
	"""

	def __init__ (self, prefix):
		self.prefix = prefix
		self.ip_network = ipaddress.ip_network (u'%s' % prefix, strict = False)


	def __eq__ (self, other):
		if isinstance (other, Prefix):
			return self.ip_network == other.ip_network

		return NotImplemented

	def __lt__ (self, other):
		if isinstance (other, Prefix):
			return self.ip_network < other.ip_network

		return NotImplemented


	def __str__ (self):
		return self.prefix


	@property
	def ip (self):
		return self.prefix.split ('/')[0]

	@property
	def af (self):
		return self.ip_network.version

	@property
	def plen (self):
		return self.ip_network.prefixlen

	@property
	def netmask (self):
		return self.ip_network.netmask

	@property
	def network_address (self):
		return self.ip_network.network_address


################################################################################
#                                  Functions                                   #
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
#    00:00	being the BATMAN interface
#    00:0d	being the dummy interface
#    00:0f	being the VEth internal side interface
#    00:e0	being an external instance BATMAN interface
#    00:ed	being an external instance dummy interface
#    00:e1	being an inter-gw-vpn interface
#    00:e4	being an nodes fastd tunnel interface of IPv4 transport
#    00:e6	being an nodes fastd tunnel interface of IPv6 transport
#    00:ef	being an extenral instance VEth interface side
#    02:xx	being a connection to local Vlan 2xx
#    xx:xx	being a VXLAN tunnel for site ss, with xx being the underlay VLAN ID (1xyz, 2xyz)
#    ff:ff	being the gluon next-node interface
def gen_batman_iface_mac (site_no, device_no, network):
	net_type_map = {
		'bat'     : "00:00",
		'dummy'   : "00:0d",
		'int2ext' : "00:0f",
		'bat-e'   : "00:e0",
		'intergw' : "00:e1",
		'nodes4'  : "00:e4",
		'nodes6'  : "00:e6",
		'dummy-e' : "00:ed",
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
	except (KeyError,ValueError):
		node_batman_hop_penalty = None

	iface_config = node_config['ifaces'][iface]
	iface_type = iface_config.get ('type', 'inet')
	batman_config = {}

	for item in list (iface_config.keys ()):
		value = iface_config.get (item)
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
						break

				if 'batman_ext' in node_roles and iface.endswith('-ext'):
					batman_config['batman-hop-penalty'] = default_hop_penalty_by_role['batman_ext']

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

	to_pop = []

	for item, value in config.items ():
		if item.startswith ('bond-'):
			bond_config[item] = value
			to_pop.append (item)

	for item in to_pop:
		config.pop (item)

	if bond_config['bond-mode'] not in ['2', 'balance-xor', '4', '802.3ad']:
		bond_config.pop ('bond-xmit-hash-policy')

	config['bond'] = bond_config


# Mangle bridge specific config items with default values and store them in
# separate sub-dict for easier access and configuration.
def _update_bridge_config (config):
	bridge_config = default_bridge_config.copy ()

	for item in list (config.keys ()):
		value = config.get (item)
		if not item.startswith ('bridge-'):
			continue

		bridge_config[item] = value
		config.pop (item)

		# Fix any salt mangled string interpretation back to real string.
		if type (value) == bool:
			bridge_config[item] = "yes" if value else "no"

	# If bridge ports were specified as a list - which they should -
	# generate a sorted list of interface names as string representation
	if 'bridge-ports' in bridge_config and type (bridge_config['bridge-ports']) == list:
		bridge_ports_str = " ".join (sorted (bridge_config['bridge-ports']))
		if not bridge_ports_str:
			bridge_ports_str = "none"

		bridge_config['bridge-ports'] = bridge_ports_str

	if config.get ('vlan-mode') == 'tagged':
		bridge_config['bridge-vlan-aware'] = 'yes'

		if config.get ('tagged_vlans'):
			bridge_config['bridge-vids'] = " ".join (map (str, config['tagged_vlans']))

	config['bridge'] = bridge_config


# Generate config options for vlan-aware-bridge member interfaces
def _update_bridge_member_config (config):
	bridge_config = {}

	if config.get ('tagged_vlans'):
                        bridge_config['bridge-vids'] = " ".join (map (str, config['tagged_vlans']))

	config['bridge'] = bridge_config


# Move vlan specific config items into a sub-dict for easier access and pretty-printing
# in the configuration file
def _update_vlan_config (config):
	vlan_config = {}

	for item in list (config.keys ()):
		value = config.get (item)
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


# The given MTU to the given interface - presented by it's interface config dict -
# IFF no MTU has already been set in the node pillar.
#
# @param ifaces:	All interface configuration (as dict)
# @param iface_name:	Name of the interface to set MTU for
# @param mtu:		The MTU value to set (integer)
#			When <mtu> is <= 0, the <mtu> configured for <iface_name>
#			will be used to set the MTU of the upper interface, and the
#			default MTU if none is configured explicitly.
def _set_mtu_to_iface_and_upper (ifaces, iface_name, mtu):
	iface_config = ifaces.get (iface_name)

	# By default we assume that we should set the given MTU value as the 'automtu'
	# attribute to allow distinction between manually set and autogenerated MTU
	# values.
	set_automtu = True

	# If a mtu values <= 0 is given, use the MTU configured for this interface
	# or, if none is set, the default value when configuring the vlan-raw-device.
	if mtu <= 0:
		set_automtu = False
		mtu = iface_config.get ('mtu', MTU['default'])

	# If this interface already has a MTU set - probably because someone manually
	# specified one in the node pillar - we do not touch the MTU of this interface.
	# Nevertheless it's worth looking at any underlying interface.
	if 'mtu' in iface_config:
		set_automtu = False

	# There might be - read: "we have" - a situation where on top of e.g. bond0
	# there are vlans holding VXLAN communicaton as well as VLANs directly carrying
	# BATMAN traffic. Now depending on which interface is evaluated first, the upper
	# MTU is either correct, or maybe to small.
	#
	# If any former autogenerated MTU is greater-or-equal than the one we want to
	# set now, we'll ignore it, and go for the greater one.
	elif 'automtu' in iface_config and iface_config['automtu'] >= mtu:
		set_automtu = False

	# If we still consider this a good move, set given MTU to this device.
	if set_automtu:
		iface_config['automtu'] = mtu

	# If this is a VLAN - which it probably is - fix the MTU of the underlying interface, too.
	# Check for 'vlan-raw-device' in iface_config and in vlan subconfig (yeah, that's not ideal).
	vlan_raw_device = None
	if 'vlan-raw-device' in iface_config:
		vlan_raw_device = iface_config['vlan-raw-device']
	elif 'vlan' in iface_config and 'vlan-raw-device' in iface_config['vlan']:
		vlan_raw_device = iface_config['vlan']['vlan-raw-device']

	if vlan_raw_device:
		vlan_raw_device_config = ifaces.get (vlan_raw_device, None)

		# vlan-raw-device might point to ethX which usually isn't configured explicitly
		# as ifupdown2 simply will bring it up anyway by itself. To set the MTU of such
		# an interface we have to add a configuration stanza for it here.
		if vlan_raw_device_config == None:
			vlan_raw_device_config = {}
			ifaces[vlan_raw_device] = vlan_raw_device_config

		# If there is a manually set MTU for this device, we don't do nothin'
		if 'mtu' in vlan_raw_device_config:
			return

		if 'automtu' in vlan_raw_device_config and vlan_raw_device_config['automtu'] >= mtu:
			return

		vlan_raw_device_config['automtu'] = mtu

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
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, 'bat'),
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
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, 'bat-e'),
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
				'mtu' : MTU['batman_underlay_iface'],
				'ext_only' : True,
			},

			# Optional VEth interface pair - "external" side
			ext2int_site_if : {
				'link-type' : 'veth',
				'veth-peer-name' : int2ext_site_if,
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, 'ext2int'),
				'mtu' : MTU['batman_underlay_iface'],
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

		# Configure bat_site_if to be part of br-<site>, if present
		site_bridge = "br-%s" % site
		if site_bridge in ifaces:
			bridge_config = ifaces.get (site_bridge)
			bridge_ports = bridge_config.get ('bridge-ports', None)
			# There are bridge-ports configured already, but bat_site_if is not present
			if bridge_ports and bat_site_if not in bridge_ports:
				if type (bridge_ports) == list:
					bridge_ports.append (bat_site_if)
				else:
					bridge_config['bridge-ports'] += ' ' + bat_site_if

			# There are no bridge-ports configured
			if not bridge_ports:
				bridge_config['bridge-ports'] = bat_site_if


	# Make sure there is a bridge present for every site where a mesh_breakout
	# interface should be configured.
	for iface in list (ifaces.keys ()):
		config = ifaces.get (iface)
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
			batman_ifaces = ifaces[batman_site_if]['batman-ifaces']
			if iface not in batman_ifaces:
				if type (batman_ifaces) == list:
					batman_ifaces.append (iface)
				else:
					batman_ifaces += ' ' + iface

			# Use the MTU configured for this interface or, if none is set,
			# the default value for batman underlay iface.
			mtu = config.get('mtu', MTU['batman_underlay_iface'])
			_set_mtu_to_iface_and_upper (ifaces, iface, mtu)


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

	for iface in list (ifaces.keys ()):
		iface_config = ifaces.get (iface)
		batman_connect_sites = iface_config.get ('batman_connect_sites', [])
		iface_has_prefixes = len (iface_config.get ('prefixes', {})) != 0

		# If we got a string, convert it to a list with a single element
		if type (batman_connect_sites) == str:
			batman_connect_sites = [ batman_connect_sites ]

		# If the list of sites to connect is empty, there's nothing to do here.
		if len (batman_connect_sites) == 0:
			continue

		# Set the MTU of this (probably) VLAN device to the MTU required for a VXLAN underlay
		# device, where B.A.T.M.A.N. adv. is to be expected within the VXLAN overlay.
		# If there are NO IPs configured on this interface, it means we will be using IPv6 LLAs
		# to set up VXLAN tunnel endpoints, so we need more headroom header-wise.
		underlay_mtu = MTU['vxlan_underlay_iface']
		if not iface_has_prefixes:
			underlay_mtu = MTU['vxlan_underlay_iface_ipv6']

		_set_mtu_to_iface_and_upper (ifaces, iface, underlay_mtu)

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
			bat_iface = "bat-%s" % site

			# If there's no batman interface for this site, there's no point
			# in setting up a VXLAN interfaces
			if bat_iface not in ifaces:
				continue

			# bail out if VXLAN tunnel already configured
			if vx_iface in ifaces:
				continue

			try:
				iface_id = int (re.sub ('vlan', '', iface))

				# Gather interface specific mcast address.
				# The address is derived from the vlan-id of the underlying interface,
				# assuming that it in fact is a vlan interface.

				# Mangle the vlan-id into two 2 digit values, eliminating any leading zeros.
				iface_id_4digit = "%04d" % iface_id
				octet2 = int (iface_id_4digit[0:2])
				octet3 = int (iface_id_4digit[2:4])
				vni = octet2 * 256 * 256 + octet3 * 256 + site_no

				vtep_config = {
					'vxlan-id' : vni,
					'vxlan-physdev' : iface,
				}

				# If there are prefixes configured on this underlay interface go for legacy IPv4 Multicast (for now)
				if iface_has_prefixes:
					vtep_config['vxlan-svcnodeip'] = "225.%s.%s.%s" % (octet2, octet3, site_no)
				else:
					vtep_config['vxlan-remote-group'] = "ff42:%s::%s" % (iface_id, site_no)

			except ValueError as v:
				vtep_config = {
					'vxlan-config-error' : str (v),
				}

				iface_id = 9999
				mcast_ip = "225.0.0.%s" % site_no
				vni = site_no

			# Add the VXLAN interface
			ifaces[vx_iface] = {
				'vxlan' : vtep_config,
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, iface_id),
				'mtu'       : MTU['batman_underlay_iface'],
			}

			iface_penalty = get_batman_iface_penalty (iface)
			if iface_penalty:
				ifaces[vx_iface]['batman'] = {
					'batman-hop-penalty' : iface_penalty
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
	for iface in list (ifaces.keys ()):
		iface_config = ifaces.get (iface)
		vrf = iface_config.get ('vrf', None)
		if vrf is None or vrf in ifaces:
			continue

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
	# If this node has primary_ips set and filled there are either IPs
	# configured on lo or IPs on another interface - possibly ones on
	# the only interface present - are considered as primary IPs.
	if node_config.get ('primary_ips', False):
		return

	v4_ip = "%s/32"  % get_primary_ip (node_config, 'v4').ip
	v6_ip = "%s/128" % get_primary_ip (node_config, 'v6').ip

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

# Generate interface descriptions / aliases for auto generated or manually
# created interfaces. Currently this only is done for bridges associated
# with BATMAN instanzes.
#
# @param node_config:	The configuration of the given node (as dict)
# @param sites_config	Global sites configuration (as dict)
def _update_interface_desc (node_config, sites_config):
	# Currently we only care for nodes with batman role.
	if 'batman' not in node_config.get ('roles', []):
		return

	for iface, iface_config in node_config.get ('ifaces', {}).items ():
		if 'desc' in sites_config:
			continue

		# If the interface name looks like a bridge for a BATMAN instance
		# try to get the name of the corresponding site
		match = re.search (r'^br-([a-z_-]+)$', iface)
		if match and match.group (1) in sites_config:
			try:
				iface_config['desc'] = sites_config[match.group (1)]['name']
			except KeyError:
				pass


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
	# Make a copy of the node_config dictionary to suppress side-effects.
	# This function deletes some keys from the node_config which will break
	# any re-run of this function or other functions relying on the node_config
	# to be complete.
	node_config = deepcopy (node_config)

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
	for interface in list (ifaces.keys ()):
		config = ifaces.get (interface)
		iface_type = config.get ('type', 'inet')

		# Remove any disable interfaces here as they aren't relevant for /e/n/i
		if config.get ('enabled', True) == False:
			del ifaces[interface]
			continue

		# Ignore interfaces used for PPPoE
		if 'pppoe' in config.get ('tags', []):
			del ifaces[interface]
			continue

		if 'batman-ifaces' in config or iface_type.startswith ('batman'):
			_update_batman_config (node_config, interface, sites_config)

		if 'bond-slaves' in config:
			_update_bond_config (config)

		# FIXME: This maybe will not match on bridges without any member ports configured!
		if 'bridge-ports' in config or interface.startswith ('br-'):
			_update_bridge_config (config)

		if 'bridge-member' in config:
			_update_bridge_member_config (config)

		if 'vlan-raw-device' in config or 'vlan-id' in config:
			_update_vlan_config (config)
			_set_mtu_to_iface_and_upper (ifaces, interface, 0)

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
		if interface != 'lo' and ('mtu' not in config):
			# Set the MTU value of this interface to the autogenerated value (if any)
			# or set the default, when no automtu is present.
			config['mtu'] = config.get ('automtu', MTU['default'])

		for key in [ 'automtu', 'enabled', 'batman_connect_sites', 'bridge-member', 'has_gateway', 'ospf', 'site', 'type', 'tagged_vlans', 'vlan-mode' ]:
			if key in config:
				config.pop (key)

		# Remove route metric on non-router nodes
		if 'metric' in config and not 'router' in node_config.get ('roles', []):
			config.pop ('metric')

	# This leaves 'auto', 'prefixes' and 'desc' as keys which should not be directly
	# printed into the remaining configuration. These are handled within the jinja
	# interface template.

	# Generate meaningful interface descriptions / aliases where useful
	_update_interface_desc (node_config, sites_config)

	return ifaces


vlan_vxlan_iface_re = re.compile (r'^vlan(\d+)|^vx_v(\d+)_(\w+)')

def _iface_sort (iface_a, iface_b):
	a = vlan_vxlan_iface_re.search (iface_a)
	b = vlan_vxlan_iface_re.search (iface_b)

	# At least one interface didn't match, do regular comparison
	if not a or not b:
		return ffho.cmp (iface_a, iface_b)

	# Extract VLAN ID from VLAN interface (if given) or VXLAN
	vid_a = a.group (1) if a.group (1) else a.group (2)
	vid_b = b.group (1) if b.group (1) else b.group (2)

	# If it's different type of interfaces (one VLAN, one VXLAN), do regular comparison
	if (a.group (1) == None) != (b.group (1) == None):
		return ffho.cmp (iface_a, iface_b)

	# Ok, t's two VLAN or two VXLAN interfaces

	# If it's VXLAN interfaces and the VLAN ID is the same, sort by site name
	if a.group (2) and vid_a == vid_b:
		return ffho.cmp (a.groups (2), b.groups (2))

	# If it's two VLANs or two VXLANs with different VLAN IDs, sort by VLAN ID
	else:
		return ffho.cmp (int (vid_a), int (vid_b))


def get_interface_list (ifaces):
	iface_list = []

	for iface in sorted (ifaces.keys (), key = cmp_to_key (_iface_sort)):
		iface_list.append (iface)

	return iface_list


# Generate entries for /etc/bat-hosts for every batman interface we will configure on any node.
# For readability purposes superflous/redundant information is being stripped/supressed.
# As these names will only show up in batctl calls with a specific site, site_names in interfaces
# are stripped. Dummy interfaces are stripped as well.
def gen_bat_hosts (nodes_config, sites_config):
	bat_hosts = {}

	for node_id in sorted (nodes_config.keys ()):
		node_config = nodes_config.get (node_id)
		node_name = node_id.split ('.')[0]

		if 'batman' not in node_config['roles']:
			continue

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


# Return the appropriate hop penalty to configure for the given interface.
def get_batman_iface_penalty (iface):
	if iface.startswith ('vlan'):
		vid = int (re.sub ('vlan', '', iface))
		if 1400 <= vid < 1500:
			return default_batman_iface_penalty_by_role.get ('DCI')

		if 2000 <= vid < 2100:
			return default_batman_iface_penalty_by_role.get ('WBBL')

		if 2200 <= vid < 2300:
			return default_batman_iface_penalty_by_role.get ('WBBL_backup')

	if 'intergw' in iface:
		return default_batman_iface_penalty_by_role.get ('VPN_intergw')

	if 'nodes' in iface:
		return default_batman_iface_penalty_by_role.get ('VPN_node')

	return default_batman_iface_penalty_by_role.get ('default', 0)


# Generate eBGP session parameters for FFRL Transit from nodes pillar information.
def get_ffrl_bgp_config (ifaces, proto):
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
				neighbor = str (ipaddress.ip_address (u'%s' % local) - 1)

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
#			OR name of VRF ("vrf_<something>") whichs ifaces are
#			to be examined.
# @param: with_mask	Don't strip the netmask from the prefix. (Default false)
def get_node_iface_ips (node_config, iface_name, with_mask = False):
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

				if not with_mask:
					prefix = prefix.split ('/')[0]
				ips[ip_ver].append (prefix)
	except KeyError:
		pass

	return ips


#
# Get the primary IP(s) of the given node
#
# @param node_config:   Pillar node configuration (as dict)
# @param af:		Address family
def get_primary_ip (node_config, af):
	# Compatility glue
	if 'primary_ips' not in node_config:
		return Prefix ("%s%s" % (loopback_prefix[af], node_config['id']))

	return Prefix (node_config['primary_ips'][af])


#
# Get the router id (read: IPv4 Lo-IP) out of the given node config.
def get_router_id (node_config, node_id):
	return get_primary_ip (node_config, 'v4').ip



# Compute minions OSPF interface configuration according to FFHO routing policy
# See https://wiki.ffho.net/infrastruktur:vlans for information about Vlans
#
# Costs are based on the following reference values:
#
# Iface speed |  Cost
# ------------+---------
# 100 Gbit/s  |      1
#  40 Gbit/s  |      2
#  25 Gbit/s  |      4
#  20 Gbit/s  |      5
#  10 Gbit/s  |     10
#   1 Gbit/s  |    100
# 100 Mbit/s  |   1000
#    VPN      |  10000
#
def get_ospf_config (node_config, grains_id):
	ospf_config = {
		# <area> : {
		#	<iface> : {
		#		config ...
		#	}
		# }
	}

	for iface, iface_config in node_config.get ('ifaces', {}).items ():
		# By default we don't speak OSPF on interfaces
		ospf_on = False
		area = 0

		# Defaults for OSPF interfaces
		ospf_iface_cfg = {
			'stub' : True,			# Active/Passive interface
			'cost' : 12345,
			# 'type' 			# Area type
		}

		# OSPF configuration for interface present?
		ospf_iface_cfg_pillar = iface_config.get ('ospf', {})

		# Should be completely ignore this interface?
		if ospf_iface_cfg_pillar.get ('ignore', False):
			continue

		# Ignore interfaces without any IPs configured
		if not iface_config.get ('prefixes'):
			continue

		# If this interface is within a (non-default) VRF, don't OSPF here
		if iface_config.get ('vrf'):
			continue

		# Wireless Local Links (WLL)
		if re.search (r'^vlan90\d$', iface):
			ospf_on = True
			ospf_iface_cfg['stub'] = True
			ospf_iface_cfg['cost'] = 10
			ospf_iface_cfg['desc'] = "Wireless Local Link (WLL)"

		# Local Gigabit Ethernet based connections (PTP or L2 subnets), cost 10
		elif re.search (r'^(br-?|br\d+\.|vlan)10\d\d$', iface):
			ospf_on = True
			ospf_iface_cfg['stub'] = False
			ospf_iface_cfg['cost'] = 100
			ospf_iface_cfg['desc'] = "Wired Gigabit connection"

		# 10/20 Gbit/s Dark Fiber connection
		elif re.search (r'^vlan12\d\d$', iface):
			ospf_on = True
			ospf_iface_cfg['stub'] = False
			ospf_iface_cfg['cost'] = 10
			ospf_iface_cfg['desc'] = "Wired 10Gb/s connection"

		# VLL connection
		elif re.search (r'^vlan15\d\d$', iface):
			ospf_on = True
			ospf_iface_cfg['stub'] = False
			ospf_iface_cfg['cost'] = 200
			ospf_iface_cfg['desc'] = "VLL connection"

		# WBBL connection
		elif re.search (r'^vlan20\d\d$', iface):
			ospf_on = True
			ospf_iface_cfg['stub'] = False
			ospf_iface_cfg['cost'] = 1000
			ospf_iface_cfg['desc'] = "WBBL connection"

		# Legacy WBBL connection
		elif re.search (r'^vlan22\d\d$', iface):
			ospf_on = True
			ospf_iface_cfg['stub'] = False
			ospf_iface_cfg['cost'] = 1000
			ospf_iface_cfg['desc'] = "WBBL connection"

		# Management Vlans
		elif re.search (r'^vlan30\d\d$', iface):
			ospf_on = True
			ospf_iface_cfg['stub'] = True
			ospf_iface_cfg['cost'] = 10

		# Management X-Connects
		elif re.search (r'^vlan32\d\d$', iface):
			ospf_on = True
			ospf_iface_cfg['stub'] = False
			ospf_iface_cfg['cost'] = 10
			ospf_iface_cfg['AF'] = 4
			area = 51

		# OPS Vlans
		elif re.search (r'^vlan39\d\d$', iface):
			ospf_on = True
			ospf_iface_cfg['stub'] = True
			ospf_iface_cfg['cost'] = 10

		# Active OSPF on OpenVPN tunnels, cost 10000
		elif iface.startswith ('ovpn-'):
			ospf_on = True
			ospf_iface_cfg['stub'] = False
			ospf_iface_cfg['cost'] = 10000

			# Inter-Core links should have cost 5000
			if iface.startswith ('ovpn-cr') and grains_id.startswith ('cr'):
				ospf_iface_cfg['cost'] = 5000

			# OpenVPN tunnels to EdgeRouters
			elif iface.startswith ('ovpn-er-'):
				ospf_iface_cfg['type'] = 'broadcast'

		# Active OSPF on Wireguard tunnels, cost 10000
		elif iface.startswith ('wg-'):
			ospf_on = True
			ospf_iface_cfg['stub'] = False
			ospf_iface_cfg['cost'] = 10000

			# Inter-Core links should have cost 5000
			if iface.startswith ('wg-cr') and grains_id.startswith ('cr'):
				ospf_iface_cfg['cost'] = 5000

		# Passive OSPF on OOBM Wireguard tunnels on server side, cost 10
		elif iface.startswith ('oob-'):
			# Only activate OSPF on core router side
			if not grains_id.startswith ('cr'):
				continue

			ospf_on = True
			ospf_iface_cfg['stub'] = True
			ospf_iface_cfg['cost'] = 10

		# OSPF explicitly enabled for interface
		elif 'ospf' in iface_config:
			ospf_on = True
			# iface ospf parameters will be applied later


		# Go on if OSPF should not be actived
		if not ospf_on:
			continue

		# Explicit OSPF interface configuration parameters take precendence over generated ones
		for attr, val in ospf_iface_cfg_pillar.items ():
			ospf_iface_cfg[attr] = val

		# Store interface configuration
		if area not in ospf_config:
			ospf_config[area] = {}

		ospf_config[area][iface] = ospf_iface_cfg

	return ospf_config


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


# Convert the CIDR network from the given prefix into a dotted netmask
def cidr_to_dotted_mask (prefix):
	return str (ipaddress.ip_network (prefix, strict = False).netmask)

def is_subprefix (prefix, subprefix):
	p = ipaddress.ip_network (prefix, strict = False)
	s = ipaddress.ip_network (subprefix, strict = False)

	return s.subnet_of (p)

# Return the network address of the given prefix
def get_network_address (prefix, with_prefixlen = False):
	net_h = ipaddress.ip_network (u'%s' % prefix, strict = False)
	network = str (net_h.network_address)

	if with_prefixlen:
		network += "/%s" % net_h.prefixlen

	return network

# Return a dict of all VRF names by their table ID
def get_vrfs_by_id():
	vrfs = {}

	for vrf_name, cfg in vrf_info.items():
		vrfs[cfg['table']] = vrf_name

	return vrfs

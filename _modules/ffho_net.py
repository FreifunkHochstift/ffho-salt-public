#!/usr/bin/python

import re

mac_prefix = "f2"

vrf_table_map = {
	'vrf_external' : 1023,
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
#    00:01	being an inter-gw-vpn interface
#    00:04	being an nodes fastd tunnel interface of IPv4 transport
#    00:06	being an nodes fastd tunnel interface of IPv6 transport
#    02:xx	being a connection to local Vlan 2xx
#    07:xx	being a VXLAN tunnel for site ss, with xx being a consecutive number
#    1b:24	being the ibss 2.4GHz bssid
#    1b:05	being the ibss 5GHz bssid
#    ff:ff	being the gluon next-node interface
def gen_batman_iface_mac (site_no, device_no, network):
	net_type_map = {
		'dummy'   : 0,
		'intergw' : 1,
		'nodes4'  : 4,
		'nodes6'  : 6,
	}

	# Well-known network type?
	if network in net_type_map:
		network = net_type_map[network]

	if type (network) == int:
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


# Generate configuration entries for any batman related interfaces not
# configured explicitly, but asked for implicitly by role batman and a
# (list of) site(s) specified in the node config.
def _generate_batman_interface_config (node_config, ifaces, sites_config):
	# No role 'batman', nothing to do
	if 'batman' not in node_config.get ('roles', []):
		return

	device_no = node_config.get ('id', -1)

	for site in node_config.get ('sites', []):
		bat_site_if = "bat-%s" % site
		dummy_site_if = "dummy-%s" % site
		site_no = _get_site_no (sites_config, site)

		# Create bat-<site> interface config
		if bat_site_if not in ifaces:
			ifaces[bat_site_if] = {
				'type' : 'batman',
				'batman-ifaces' : [ dummy_site_if ],
				'batman-ifaces-ignore-regex': '.*_.*',
			}

		# Create dummy-<site> interfaces config to ensure bat-<site> can
		# be successfully configured (read: comes up)
		if not dummy_site_if in ifaces:
			ifaces[dummy_site_if] = {
				'link-type' : 'dummy',
				'hwaddress' : gen_batman_iface_mac (site_no, device_no, 'dummy')
			}


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
			ifaces[vrf] = {
				'vrf-table' : vrf_table_map.get (vrf, 1234)
			}


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


def get_interface_config (nodes_config, node_id, sites_config):
	# Get config of this node and dict of all configured ifaces
	node_config = nodes_config.get (node_id, {})
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

		ifaces = get_interface_config (nodes_config, node_id, sites_config)
		for iface in sorted (ifaces):
			iface_config = ifaces.get (iface)

			hwaddress = iface_config.get ('hwaddress', None)
			if hwaddress == None:
				continue

			entry_name = node_name
			if not iface.startswith ('dummy-'):
				entry_name += "/%s" % re.sub (r'^(vx_.*)_(.*)$', '\g<1>', iface)

			bat_hosts[hwaddress] = entry_name

		if 'fastd' in node_config.get ('roles', []):
			device_no = node_config.get ('id')
			for site in node_config.get ('sites', []):
				site_no = _get_site_no (sites_config, site)

				for network in ('intergw', 'nodes4', 'nodes6'):
					hwaddress = gen_batman_iface_mac (site_no, device_no, network)
					bat_hosts[hwaddress] = "%s/%s" % (node_name, network)

	return bat_hosts

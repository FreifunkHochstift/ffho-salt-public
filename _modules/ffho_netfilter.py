#
# FFHO netfilter helper functions
#

import ipaddress
import re

import ffho_net


# Prepare regex to match VLAN intefaces / extract IDs
vlan_re = re.compile (r'^(vlan|br0\.)(\d+)$')

################################################################################
#                          Internal helper functions                           #
################################################################################

#
# Check if at least one of the node roles are supposed to run DHCP
def _allow_dhcp (fw_policy, roles):
	for dhcp_role in fw_policy.get ('dhcp_roles', []):
		if dhcp_role in roles:
			return True

	return False


# Generate services rules for the given AF
def _generate_service_rules (services, acls, af):
	rules = []

	for srv in services:
		rule = ""
		comment = srv['descr']
		acl_comment = ""
		src_prefixes = []

		# If there are no DST IPs set at all or DST IPs for this AF set, we have a rule to build,
		# if this is NOT the case, there is no rule for this AF to generate, carry on.
		if not ((not srv['ips']['4'] and not srv['ips']['6']) or srv['ips'][str(af)]):
			continue

		# Is/are IP(s) set for this service?
		if srv['ips'][str(af)]:
			rule += "ip" if af == 4 else "ip6"

			dst_ips = srv['ips'][str(af)]
			if len (dst_ips) == 1:
				rule += " daddr %s " % dst_ips[0]
			else:
				rule += " daddr { %s } " % ", ".join (dst_ips)

		# ACLs defined for this service?
		if srv['acl']:
			srv_acl = sorted (srv['acl'])
			for ace in srv_acl:
				ace_pfx = (acls[ace][af])

				# Many entries
				if type (ace_pfx) == list:
					src_prefixes.extend (ace_pfx)
				else:
					src_prefixes.append (ace_pfx)

			acl_comment = "acl: %s" % ", ".join (srv_acl)

		# Additional prefixes defined for this service?
		if srv['additional_prefixes']:
			add_pfx = []
			# Additional prefixes are given as a space separated list
			for entry in srv['additional_prefixes'].split ():
				# Strip commas and spaces, just in case
				pfx_str = entry.strip (" ,")
				pfx_obj = ipaddress.ip_network (pfx_str)

				# We only care for additional pfx for this AF
				if pfx_obj.version != af:
					continue

				add_pfx.append (pfx_str)

			if add_pfx:
				src_prefixes.extend (add_pfx)

				if acl_comment:
					acl_comment += ", "
				acl_comment += "additional pfx"

		# Combine ACL + additional prefixes (if any)
		if src_prefixes:
			rule += "ip" if af == 4 else "ip6"
			if len (src_prefixes) > 1:
				rule += " saddr { %s } " % ", ".join (src_prefixes)
			else:
				rule += " saddr %s " % src_prefixes[0]

		if acl_comment:
			comment += " (%s)" % acl_comment

		# Multiple ports?
		if len (srv['ports']) > 1:
			ports = "{ %s }" % ", ".join (map (str, srv['ports']))
		else:
			ports = srv['ports'][0]

		rule += "%s dport %s counter accept comment \"%s\"" % (srv['proto'], ports, comment)
		rules.append (rule)

	return rules


def _generate_wireguard_rule (node_config):
	ports = []

	wg = node_config.get ('wireguard')
	if not wg or not  'tunnels' in wg:
		return None

	for iface, wg_cfg in node_config['wireguard']['tunnels'].items ():
		if wg_cfg['mode'] == 'server':
			ports.append (wg_cfg['port'])

	if not ports:
		return None

	if len (ports) > 1:
		ports = "{ %s }" % ", ".join (map (str, ports))
	else:
		ports = ports[0]

	return "udp dport %s counter accept comment Wireguard" % ports


def _active_urpf (iface, iface_config):
	# Ignore loopbacks
	if iface == 'lo' or iface_config.get ('link-type', '') == 'dummy':
		return False

	# Forcefully enable/disable uRPF via tags on Netbox interface?
	if 'urpf' in iface_config:
		return iface_config['urpf']

	# No uRPF on infra VPNs
	for vpn_prefix in ["gre_", "ovpn-", "wg-"]:
		if iface.startswith (vpn_prefix):
			return False

	# No address, no uRPF
	if not iface_config.get ('prefixes'):
		return False

	# Interface in vrf_external connect to the Internet
	if iface_config.get ('vrf') in ['vrf_external']:
		return False

	# Default gateway pointing towards this interface?
	if iface_config.get ('gateway'):
		return False

	# Ignore interfaces by VLAN
	match = vlan_re.search (iface)
	if match:
		vid = int (match.group (2))

		# Magic
		if 900 <= vid <= 999:
			return False

		# Wired infrastructure stuff
		if 1000 <= vid <= 1499:
			return False

		# Wireless infrastructure stuff
		if 2000 <= vid <= 2299:
			return False

	return True


################################################################################
#                               Public functions                               #
################################################################################

#
# Generate rules to allow access to services running on this node.
# Services can either be allow programmatically here or explicitly
# as Services applied to the device/VM in Netbox
def generate_service_rules (fw_config, node_config):
	acls = fw_config.get ('acls', {})
	fw_policy = fw_config.get ('policy', {})

	services = node_config.get ('services', [])
	roles = node_config.get ('roles', [])

	rules = {
		4 : [],
		6 : [],
	}

	#
	# Add rules based on roles and tunnels
	#

	# Does this node run a DHCP server?
	if _allow_dhcp (fw_policy, roles):
		rules[4].append ('udp dport 67 counter accept comment "DHCP"')

	# Allow respondd queries on B.A.T.M.A.N. adv. nodes
	if 'batman' in roles:
		rules[6].append ('ip6 saddr fe80::/64 ip6 daddr ff05::2:1001 udp dport 1001 counter accept comment "responnd"')

	# Allow respondd replies to yanic
	if 'yanic' in roles:
		rules[6].append ('ip6 saddr fe80::/64 udp sport 1001 counter accept comment "respondd replies to yanic"')

	# Allow Wireguard tunnels
	wg_rule = _generate_wireguard_rule (node_config)
	if wg_rule:
		rules[4].append (wg_rule)

	for af in [ 4, 6 ]:
		comment = "Generated rules" if rules[af] else "No generated rules"
		rules[af].insert (0, "# %s" % comment)

	#
	# Generate and add rules for services from Netbox, if any
	#
	for af in [ 4, 6 ]:
		srv_rules = _generate_service_rules (services, acls, af)
		if not srv_rules:
			rules[af].append ("# No services defined in Netbox")
			continue

		rules[af].append ("# Services defined in Netbox")
		rules[af].extend (srv_rules)

	return rules


def generate_forward_policy (fw_config, node_config):
	policy = fw_config.get ('policy', {})
	roles = node_config.get ('roles', [])
	nf_cc = node_config.get ('nftables', {})

	fp = {
		# Get default policy for packets to be forwarded
		'policy' : 'drop',
		'policy_reason' : 'default',
		'rules': {
			4 : [],
			6 : [],
		},
	}

	if 'forward_default_policy' in policy:
		fp['policy'] = policy['forward_default_policy']
		fp['policy_reason'] = 'forward_default_policy'

	# Does any local role warrants for forwarding packets?
	accept_roles = [role for role in policy.get ('forward_accept_roles', []) if role in roles]
	if accept_roles:
		fp['policy'] = 'accept'
		fp['policy_reason'] = "roles: " + ",".join (accept_roles)

	try:
		cust_rules = nf_cc['filter']['forward']
		for af in [ 4, 6 ]:
			if af not in cust_rules:
				continue

			if type (cust_rules[af]) != list:
				raise ValueError ("nftables:filter:forward:%d in config context expected to be a list!" % af)

				fp['rules'][af] = cust_rules[af]
	except KeyError:
		pass

	return fp


def generate_mgmt_config (fw_config, node_config):
	# If this box is not a router, it will not be responsible for providing
	# access to any management network, so there's nothing to do here.
	roles = node_config.get ('roles', [])
	if 'router' not in roles:
		return None

	# Get management prefixes from firewall configuration.
	# If there are no prefixes defined, there's nothing we can do here.
	mgmt_prefixes = fw_config.get ('acls', {}).get ('Management networks', {})
	if not mgmt_prefixes:
		return None

	# We only care for IPv4 prefixes for now.
	if 4 not in mgmt_prefixes:
		return None

	config = {
		'ifaces': [],
		'prefixes': mgmt_prefixes,
	}

	mgmt_interfaces = []
	interfaces = node_config['ifaces']
	for iface in interfaces.keys ():
		match = vlan_re.match (iface)
		if match:
			vlan_id = int (match.group (2))
			if vlan_id >= 3000 and vlan_id < 3099:
				config['ifaces'].append (iface)

	if len (config['ifaces']) == 0:
		return None

	return config


def generate_nat_policy (node_config):
	roles = node_config.get ('roles', [])
	nf_cc = node_config.get ('nftables', {})

	np = {
		4 : {},
		6 : {},
	}

	# Any custom rules?
	cc_nat = nf_cc.get ('nat')
	if cc_nat:
		for chain in ['output', 'prerouting', 'postrouting']:
			if chain not in cc_nat:
				continue

			for af in [ 4, 6 ]:
				if str (af) in cc_nat[chain]:
					np[af][chain] = cc_nat[chain][str (af)]

	return np


def generate_urpf_policy (node_config):
	roles = node_config.get ('roles', [])

	# If this box is not a router, all traffic will come in via the internal/
	# external interface an uRPF doesn't make any sense here, so we don't even
	# have to look at the interfaces.
	if 'router' not in roles:
		return []

	urpf = {}
	interfaces = node_config['ifaces']

	for iface in sorted (interfaces.keys ()):
		iface_config = interfaces[iface]

		if not _active_urpf (iface, iface_config):
			continue

		# Ok this seems to be and edge interface
		urpf[iface] = {
			'iface' : iface,
			'desc' : iface_config.get ('desc', ''),
			4 : [],
			6 : [],
		}

		# Gather configure prefixes
		for address in iface_config.get ('prefixes'):
			pfx = ipaddress.ip_network (address, strict = False)
			urpf[iface][pfx.version].append ("%s/%s" % (pfx.network_address, pfx.prefixlen))

	sorted_urpf = []

	for iface in ffho_net.get_interface_list (urpf):
		sorted_urpf.append (urpf[iface])

	return sorted_urpf


#
# Get a list of interfaces which will form OSPF adjacencies
def get_ospf_active_interface (node_config):
	ifaces = []

	ospf_config = ffho_net.get_ospf_config (node_config, "doesnt_matter_here")

	for area in sorted (ospf_config.keys ()):
		area_ifaces = ospf_config[area]
		for iface in ffho_net.get_interface_list (area_ifaces):
			if not area_ifaces[iface].get ('stub', False):
				ifaces.append (iface)

	return ifaces

#
# Get a list of interfaces to allow VXLAN encapsulated traffic on
def get_vxlan_interfaces (interfaces):
	vxlan_ifaces = []

	for iface in interfaces:
		if interfaces[iface].get ('batman_connect_sites'):
			vxlan_ifaces.append (iface)

	return vxlan_ifaces

#
# Generate rules to allow access for/from monitoring systems
def generate_monitoring_rules (nodes, monitoring_cfg):
	rules = {
		4 : [],
		6 : [],
	}

	systems = {}

	# Prepare systems dict with configuration from pillar
	for sysname, cfg in monitoring_cfg.items ():
		if 'role' not in cfg:
			continue

		systems[sysname] = {
			'role' : cfg['role'],
			'nftables_rule_spec' : cfg.get ('nftables_rule_spec', ''),
			'nodes' : {
				4 : [],
				6 : [],
			},
		}

	# Gather information about monitoring systems from node configurations
	for node, node_config in nodes.items ():
		for system, syscfg in systems.items ():
			ips = node_config.get('primary_ips', {})

			if syscfg['role'] in node_config.get ('roles', []):
				for af in [4, 6]:
					ip = ips.get (str (af), "").split ('/')[0]
					if ip:
						syscfg['nodes'][af].append (ip)

	# Generate rules for all configured and found systems
	for sysname in sorted (systems.keys ()):
		syscfg = systems[sysname]

		for af in [4, 6]:
			if not syscfg['nodes'][af]:
				continue

			rule = "ip" if af == 4 else "ip6"
			rule += " saddr { "
			rule += ", ".join (sorted (syscfg['nodes'][af]))
			rule += " } "
			rule += syscfg['nftables_rule_spec']
			rule += f" counter accept comment \"{sysname.capitalize()}\""
			rules[af].append (rule)

	return rules

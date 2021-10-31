#
# FFHO netfilter helper functions
#

import ipaddress
import re

import ffho_net


# Prepare regex to match VLAN intefaces / extract IDs
vlan_re = re.compile (r'^vlan(\d+)$')

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
	# Add rules based on roles
	#

	# Does this node run a DHCP server?
	if _allow_dhcp (fw_policy, roles):
		rules[4].append ('udp dport 67 counter accept comment "DHCP"')

	# Allow respondd queries on gateways
	if 'batman_gw' in roles:
		rules[6].append ('ip6 saddr fe80::/64 ip6 daddr ff05::2:1001 udp dport 1001 counter accept comment "responnd"')

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


def _active_urpf (iface, iface_config):
	# Ignore loopbacks
	if iface == 'lo' or iface_config.get ('link-type', '') == 'dummy':
		return False

	# Forcefully enable uRPF via tags on Netbox interface?
	if 'urpf_enable' in iface_config.get ('tags', []):
		return True

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

	# Ignore interfaces by VLAN
	match = vlan_re.search (iface)
	if match:
		vid = int (match.group (1))

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


def generate_urpf_policy (interfaces):
	urpf = {}

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

	ospf_ifaces = ffho_net.get_ospf_interface_config (node_config, "doesnt_matter_here")

	for iface in ffho_net.get_interface_list (ospf_ifaces):
		if not ospf_ifaces[iface].get ('stub', False):
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

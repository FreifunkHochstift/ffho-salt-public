#
# FFHO netfilter helper functions
#

import ipaddress
import re

import ffho_net

def generate_service_rules (services, acls, af):
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


def generate_forward_policy (policy, roles, config_context):
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
		cust_rules = config_context['filter']['forward']
		for af in [ 4, 6 ]:
			if af not in cust_rules:
				continue

			if type (cust_rules[af]) != list:
				raise ValueError ("nftables:filter:forward:%d in config context expected to be a list!" % af)

				fp['rules'][af] = cust_rules[af]
	except KeyError:
		pass

	return fp


def generate_nat_policy (roles, config_context):
	np = {
		4 : {},
		6 : {},
	}

	# Any custom rules?
	cc_nat = config_context.get ('nat')
	if cc_nat:
		for chain in ['output', 'prerouting', 'postrouting']:
			if chain not in cc_nat:
				continue

			for af in [ 4, 6 ]:
				if str (af) in cc_nat[chain]:
					np[4][chain] = cc_nat[chain][str (af)]

	return np


def generate_urpf_policy (interfaces):
	urpf = {}

	vlan_re = re.compile (r'^vlan(\d+)$')

	for iface in sorted (interfaces.keys ()):
		iface_config = interfaces[iface]

		# Ignore loopback and VPNs
		if iface == "lo" or iface.startswith ("ovpn-") or iface.startswith ("wg-"):
			continue

		# No addres, no uRPF
		if not iface_config.get ('prefixes'):
			continue

		# Interface in vrf_external connect to the Internet
		if iface_config.get ('vrf') in ['vrf_external']:
			continue

		# Ignore interfaces by VLAN
		match = vlan_re.search (iface)
		if match:
			vid = int (match.group (1))

			# Magic
			if 900 <= vid <= 999:
				continue

			# Wired infrastructure stuff
			if 1000 <= vid <= 1499:
				continue

			# Wireless infrastructure stuff
			if 2000 <= vid <= 2299:
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

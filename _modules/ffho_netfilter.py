#
# FFHO netfilter helper functions
#

def generate_service_rules (services, acls, af):
	rules = []

	for srv in services:
		rule = ""
		comment = srv['descr']

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

		# ACL defined for this service?
		if srv['acl']:
			rule += "ip" if af == 4 else "ip6"
			acl = acls[srv['acl']][af]

			# Many entries
			if type (acl) == list:
				rule += " saddr { %s } " % ", ".join (acl)
			else:
				rule += " saddr %s " % acl

			comment += " (acl: %s)" % srv['acl']

		# Multiple ports?
		if len (srv['ports']) > 1:
			ports = "{ %s }" % ", ".join (map (str, sorted (srv['ports'])))
		else:
			ports = srv['ports'][0]

		rule += "%s dport %s counter accept comment \"%s\"" % (srv['proto'], ports, comment)
		rules.append (rule)

	return rules

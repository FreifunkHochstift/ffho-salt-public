#!/usr/bin/python3
#
# Maximilian Wilhelm <max@sdn.clinic>
#  --  Sun 23 Jul 2023 04:46:19 PM CEST
#

from functools import cmp_to_key
import ipaddress
import re

import ffho

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


def _PTR_sort (PTR_entry_a, PTR_entry_b):
	PTR_a_octets = PTR_entry_a.split('.')
	PTR_b_octets = PTR_entry_b.split('.')

	# If both PTRs smell like IPv4, calculate 16 bit value and compare
	if len(PTR_a_octets) == 2 and len(PTR_b_octets) == 2:
		# Try to parse the octets as int and compare the values
		try:
			a_val = int(PTR_a_octets[1]) * 256 + int(PTR_a_octets[0])
			b_val = int(PTR_b_octets[1]) * 256 + int(PTR_b_octets[0])
			return ffho.cmp(a_val, b_val)
		except ValueError:
			# If that fails, falls back to comparing regularly
			pass

	# If both PTRs smell like an IPv6 PTR, reverse them and sort
	if len(PTR_entry_a) > 7 and len(PTR_entry_b) > 7:
		return ffho.cmp(PTR_entry_a[::-1], PTR_entry_b[::-1])

	return ffho.cmp(PTR_entry_a, PTR_entry_b)


def generate_DNS_entries (nodes_config, sites_config):
	forward_zone_name = ""
	forward_zone = []
	zones = {
		# <forward_zone_name>: [],
		# <rev_zone1_name>: [],
		# <rev_zone2_name>: [],
		# ...
	}

	zone_entries = {
		# <zone> : {
		#	<RR> : <value>
		# },
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
				zone_entries[zone] = {}


	# Process all interfaace of all nodes defined in pillar and generate forward
	# and reverse entries for all zones defined in DNS_zone_names. Automagically
	# put reverse entries into correct zone.
	for fqdn in sorted (nodes_config):
		node_config = nodes_config.get (fqdn)
		ifaces = node_config.get("ifaces", {})

		for iface in sorted (ifaces):
			iface_config = ifaces.get (iface)

			# We only care for interfaces with IPs configured
			prefixes = iface_config.get ("prefixes", None)
			if prefixes is None:
				continue

			# Ignore any interface in $VRF
			if iface_config.get ('vrf') is not None:
				continue

			if iface in ["anycast_srv", "srv"] or "_" in iface:
				continue

			for prefix in sorted (prefixes):
				ip = ipaddress.ip_address (u'%s' % prefix.split ('/')[0])
				proto = 'v%s' % ip.version

				# The entry name is
				#             <fqdn>         if it's the primary IP
				# <interface>.<fqdn>         else

				entry_name = "%s.%s" % (iface, fqdn)
				if prefix == node_config['primary_ips'].get(str(ip.version)):
					entry_name = fqdn

				# Ignore any anycast or service IP, or anything else configured on lo
				elif iface in ["lo"]:
					continue

				# Strip forward zone name from entry_name and store forward entry
				# with correct entry type for found IP address.
				forward_entry_name = re.sub (forward_zone_name, "", entry_name)
				forward_entry_typ = "A      " if ip.version == 4 else "AAAA   "
				# Longtest value currently present is 25 chars, so aling for 32 chars
				indent = "    " + " " * (32 - len(forward_entry_name))
				forward_zone.append (f"{forward_entry_name}{indent}IN {forward_entry_typ} {ip}")

				# Find correct reverse zone, if configured and strip reverse zone name
				# from calculated reverse pointer name. Store reverse entry if we found
				# a zone for it. If no configured reverse zone did match, this reverse
				# entry will be ignored.
				for zone in zones:
					if ip.reverse_pointer.find (zone) > 0:
						PTR_entry = re.sub (zone, "", ip.reverse_pointer)

						# IPv6 PTRs are always the same length (for /64 prefixes)...
						indent = "    "
						# ... IPv4 are (for /16 prefixes), so align them nicely
						if ip.version == 4:
							indent += " " * (7 - len(PTR_entry))

						zone_entries[zone][PTR_entry] = f"{indent}IN PTR {entry_name}."

						break

	for zone, entries in zone_entries.items():
		if not entries:
			continue

		for PTR in sorted(entries.keys(), key = cmp_to_key(_PTR_sort)):
			zones[zone].append(f"{PTR}{entries[PTR]}")

	return zones


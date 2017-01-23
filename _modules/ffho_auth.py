#!/usr/bin/python
#
# Maximilian Wilhelm <max@rfc2324.org>
#  --  Mon 23 Jan 2017 12:21:22 AM CET
#

import collections

def _ssh_user_allowed (access_config, node_id, node_config, entry_name):
	roles = node_config.get ('roles', [])

	# Access config for the given user is the string "global"
	if type (access_config) == str:
		if access_config == "global":
			return True

	if type (access_config) not in [ dict, collections.OrderedDict ]:
        	raise Exception ("SSH configuration for entry %s seems broken!" % (entry_name))

	# String "global" found in the access config?
	elif "global" in access_config:
		return True

	# Is there an entry for this node_id in the 'nodes' list?
	elif node_id in access_config.get ('nodes', {}):
		return True

	# Should the key be allowed for any of the roles configured for this node?
	for allowed_role in access_config.get ('roles', []):
		if allowed_role in roles:
			return True

	return False


def get_ssh_authkeys (ssh_config, node_config, node_id, username):
	auth_keys = []

	for entry_name, entry in ssh_config['keys'].items ():
		access = entry.get ('access', {})
		add_keys = False

		# Skip this key if there's no entry for the given username
		if username not in access:
			continue

		user_access = access.get (username)
		if _ssh_user_allowed (user_access, node_id, node_config, entry_name):
			for key in entry.get ('pubkeys', []):
				if key not in auth_keys:
					auth_keys.append (key)

	return sorted (auth_keys)

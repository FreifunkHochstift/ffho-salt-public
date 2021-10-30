import re

def re_replace (pattern, replacement, string):
	return re.sub (pattern, replacement, string)

def re_search (pattern, string, flags = 0):
	return re.search (pattern, string, flags)

def is_bool (value):
	return type (value) == bool

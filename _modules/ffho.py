import re

def re_replace (pattern, replacement, string):
	return re.sub (pattern, replacement, string)

def re_search (pattern, string, flags = 0):
	return re.search (pattern, string, flags)

def is_bool (value):
	return type (value) == bool

def any_item_in_list (items, list):
	return len(set(items).intersection(set(list))) != 0

def cmp (x, y):
	"""
	Most generic comparator
	"""
	if x < y:
		return -1
	elif x == y:
		return 0
	else:
		return 1

#!/usr/bin/python
import urllib2
import sys
import json

def get_site_prefixes(netbox_token, url):
    headers = {
            'Authorization': 'Token ' + netbox_token,
            }

    entries = {}
    try:
        request = urllib2.Request(url, headers=headers)
        response = urllib2.urlopen(request)
	prefixes = {}
        for prefix in response:
		name = prefix.split(';')[0]
		pref = prefix.split(';')[1]
		prefixes[name] = pref.strip()
	return(prefixes)
    except Exception as e:
        return e

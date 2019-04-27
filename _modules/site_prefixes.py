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
        json_reader = json.load(response)

	site_config = {}
        for id in json_reader:
		pretty_id = id.split('-')[0]
		if pretty_id in site_config:
			site_config[pretty_id].update(json_reader[id])
		else:
			site_config[pretty_id] = json_reader[id]
	
	return(site_config)
    except Exception as e:
        return e
     

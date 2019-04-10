#!/usr/bin/python
import csv
import urllib2
import sys

def get_extra_dns_entries(netbox_token, url):
    headers = {
            'Authorization': 'Token ' + netbox_token,
            }

    entries = {}
    try:
        request = urllib2.Request(url, headers=headers)
        response = urllib2.urlopen(request)
        csv_reader = csv.DictReader(response, delimiter=';')
        for row in csv_reader:
            entries[row['host']] = {}
	    entries[row['host']]['address'] = row['address']
	    entries[row['host']]['address6'] = row['address6']
	return(entries)
    except Exception as e:
        return e
     


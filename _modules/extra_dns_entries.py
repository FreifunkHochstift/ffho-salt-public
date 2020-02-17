#!/usr/bin/python
import csv
import requests
import sys

def get_extra_dns_entries(netbox_token, url):
    headers = {
            'Authorization': 'Token ' + netbox_token,
            }

    entries = {}
    try:
        response = requests.get(url)
        csv_reader = csv.DictReader(response.text.splitlines(), delimiter=';')
        for row in csv_reader:
            entries[row['host']] = {}
            entries[row['host']]['address'] = row['address']
            entries[row['host']]['address6'] = row['address6']
        return(entries)
    except Exception as e:
        return e

print(get_extra_dns_entries('','https://nb.in.ffmuc.net/dcim/devices/?export=export_lom_switches'))

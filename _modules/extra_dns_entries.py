#!/usr/bin/python
import requests

def get_extra_dns_entries(netbox_api, netbox_token, filter):
    headers = {
        'Authorization': 'Token {}'.format(netbox_token)
    }
    url = netbox_api + "/dcim/devices/?" + filter
    entries = {}
    try:
        response = requests.get(url, headers=headers).json()
        for host in response["results"]:
            entries[host['name']] = {}
            if host['name']['primary_ip4']:
                entries[host['name']]['address'] = host['name']['primary_ip4']['address']
            if host['name']['primary_ip6']:
                entries[host['name']]['address6'] = host['name']['primary_ip6']['address']
        return(entries)
    except Exception as e:
        return e

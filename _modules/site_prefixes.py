#!/usr/bin/python
import requests
import sys
import json

def get_site_prefixes(netbox_token, url):
    try:
        response = requests.get(url)
        prefixes = {}
        for prefix in response.text.splitlines():
            if prefix != "":
                name = prefix.split(';')[0]
                pref = prefix.split(';')[1]
                prefixes[name] = pref.strip()
        return(prefixes)
    except Exception as e:
        return prefixes

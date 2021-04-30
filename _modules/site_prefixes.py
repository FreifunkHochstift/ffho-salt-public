#!/usr/bin/python
import requests
import logging

log = logging.getLogger(__name__)


def get_site_prefixes(netbox_api, netbox_token, filter):
    headers = {"Authorization": "Token {}".format(netbox_token)}
    url = netbox_api + "/ipam/prefixes/?" + filter
    prefixes = {}
    try:
        response = requests.get(url, headers=headers).json()
        for prefix in response["results"]:
            prefixes[prefix["description"]] = prefix["prefix"]
    except Exception as e:
        log.error(e)
    return prefixes

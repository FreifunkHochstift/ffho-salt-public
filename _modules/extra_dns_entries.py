#!/usr/bin/python
import requests
import logging

log = logging.getLogger(__name__)


def get_extra_dns_entries(netbox_api, netbox_token, filter):
    headers = {"Authorization": "Token {}".format(netbox_token)}
    url = netbox_api + "/dcim/devices/?" + filter
    entries = {}
    try:
        response = requests.get(url, headers=headers).json()
        for host in response["results"]:
            entries[host["name"]] = {}
            if host["primary_ip4"]:
                entries[host["name"]]["address"] = host["primary_ip4"]["address"].split(
                    "/"
                )[0]
            if host["primary_ip6"]:
                entries[host["name"]]["address6"] = host["primary_ip6"][
                    "address"
                ].split("/")[0]
    except Exception as e:
        log.error(e)
    return entries

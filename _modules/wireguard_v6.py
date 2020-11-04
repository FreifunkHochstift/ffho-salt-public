#!/usr/bin/python
import requests
import logging
import hashlib
import ipaddress
import re
from textwrap import wrap
log = logging.getLogger(__name__)

def mac2eui64(mac, prefix=None):
    '''
    Convert a MAC address to a EUI64 address
    or, with prefix provided, a full IPv6 address
    '''
    # http://tools.ietf.org/html/rfc4291#section-2.5.1
    eui64 = re.sub(r'[.:-]', '', mac).lower()
    eui64 = eui64[0:6] + 'fffe' + eui64[6:]
    eui64 = hex(int(eui64[0:2], 16) ^ 2)[2:].zfill(2) + eui64[2:]

    if prefix is None:
        return ':'.join(re.findall(r'.{4}', eui64))
    else:
        try:
            net = ipaddress.ip_network(prefix, strict=False)
            euil = int('0x{0}'.format(eui64), 16)
            return str(net[euil])
        except Exception as e:  # pylint: disable=bare-except
            return e

def generate(pubkey):
    m = hashlib.md5()

    m.update(pubkey.encode('ascii') + b'\n')
    hashed_key = m.hexdigest()
    hash_as_list = wrap(hashed_key, 2)
    temp_mac = "02:" + hash_as_list[0] + ":" + hash_as_list[1] + ":" + hash_as_list[2] + ":" + hash_as_list[3] + ":" + hash_as_list[4]

    return(mac2eui64(mac=temp_mac, prefix='fe80::/10'))
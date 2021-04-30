#!/usr/bin/python
import hashlib
import re
from salt.utils.network import mac2eui64
from textwrap import wrap


def generate(pubkey):
    m = hashlib.md5()

    m.update(pubkey.encode("ascii") + b"\n")
    hashed_key = m.hexdigest()
    hash_as_list = wrap(hashed_key, 2)
    temp_mac = (
        "02:"
        + hash_as_list[0]
        + ":"
        + hash_as_list[1]
        + ":"
        + hash_as_list[2]
        + ":"
        + hash_as_list[3]
        + ":"
        + hash_as_list[4]
    )

    return re.sub("\/\d+$", "", mac2eui64(mac=temp_mac, prefix="fe80::/10"))

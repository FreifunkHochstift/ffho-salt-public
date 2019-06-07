#!/usr/bin/env python3

import netifaces as netif
import subprocess
import sys

def call(cmdnargs):
  try:
    output = subprocess.check_output(cmdnargs, stderr=subprocess.STDOUT)
    lines = output.splitlines()
    lines = [line.decode('utf-8') for line in lines]
  except subprocess.CalledProcessError as err:
    print(err)
  except:
    print(str(sys.exc_info()[0]))
  else:
    return lines

  return []

def merge(a, b):
  if isinstance(a, dict) and isinstance(b, dict):
    d = dict(a)
    d.update({k: merge(a.get(k, None), b[k]) for k in b})
    return d

  if isinstance(a, list) and isinstance(b, list):
    return [merge(x, y) for x, y in itertools.izip_longest(a, b)]

  return a if b is None else b

def getInterfaceMAC(interface):
  try:
    interface = netif.ifaddresses(interface)
    mac = interface[netif.AF_LINK]
    return mac[0]['addr']
  except:
    return None


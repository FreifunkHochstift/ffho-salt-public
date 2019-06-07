#!/usr/bin/env python3

import socket
import re
import netifaces as netif

from lib.respondd import Respondd
import lib.helper


class Nodeinfo(Respondd):
  def __init__(self, config):
    Respondd.__init__(self, config)

  @staticmethod
  def getInterfaceAddresses(interface):
    addresses = []

    try:
      for ip6 in netif.ifaddresses(interface)[netif.AF_INET6]:
        addresses.append(ip6['addr'].split('%')[0])

      for ip in netif.ifaddresses(interface)[netif.AF_INET]:
        addresses.append(ip['addr'].split('%')[0])
    except:
      pass

    return addresses

  def getBatmanInterfaces(self, batmanInterface):
    ret = {}

    lines = lib.helper.call(['batctl', '-m', batmanInterface, 'if'])
    for line in lines:
      lineMatch = re.match(r'^([^:]*)', line)
      interface = lineMatch.group(0)

      interfaceType = ''
      if 'fastd' in self._config and interface == self._config['fastd']: # keep for compatibility
        interfaceType = 'tunnel'
      elif interface.find('l2tp') != -1:
        interfaceType = 'l2tp'
      elif 'mesh-vpn' in self._config and interface in self._config['mesh-vpn']:
        interfaceType = 'tunnel'
      elif 'mesh-wlan' in self._config and interface in self._config['mesh-wlan']:
        interfaceType = 'wireless'
      else:
        interfaceType = 'other'

      if interfaceType not in ret:
        ret[interfaceType] = []

      ret[interfaceType].append(lib.helper.getInterfaceMAC(interface))

    if 'l2tp' in ret:
      if 'tunnel' in ret:
        ret['tunnel'] += ret['l2tp']
      else:
        ret['tunnel'] = ret['l2tp']

    return ret

  @staticmethod
  def getCPUInfo():
    ret = {}

    with open('/proc/cpuinfo', 'r') as fh:
      for line in fh:
        lineMatch = re.match(r'^(.+?)[\t ]+:[\t ]+(.*)$', line, re.I)
        if lineMatch:
          ret[lineMatch.group(1)] = lineMatch.group(2)

    if 'model name' not in ret:
      ret["model name"] = ret["Processor"]

    return ret

  @staticmethod
  def getVPNFlag(batmanInterface):
    lines = lib.helper.call(['batctl', '-m', batmanInterface, 'gw_mode'])
    if re.match(r'^server', lines[0]):
      return True
    else:
      return False

  def _get(self):
    ret = {
      'hostname': socket.gethostname(),
      'network': {
        'addresses': self.getInterfaceAddresses(self._config['bridge']),
        'mesh': {
          'bat0': {
            'interfaces': self.getBatmanInterfaces(self._config['batman'])
          }
        },
        'mac': lib.helper.getInterfaceMAC(self._config['batman'])
      },
      'software': {
        'firmware': {
          'base': lib.helper.call(['lsb_release', '-is'])[0],
          'release': lib.helper.call(['lsb_release', '-ds'])[0]
        },
        'batman-adv': {
          'version': open('/sys/module/batman_adv/version').read().strip(),
#                'compat': # /lib/gluon/mesh-batman-adv-core/compat
        },
        'status-page': {
          'api': 0
        },
        'autoupdater': {
          'enabled': False
        }
      },
      'hardware': {
        'model': self.getCPUInfo()['model name'],
        'nproc': int(lib.helper.call(['nproc'])[0])
      },
      'owner': {},
      'system': {},
      'location': {},
      'vpn': self.getVPNFlag(self._config['batman'])
    }

    if 'mesh-vpn' in self._config and len(self._config['mesh-vpn']) > 0:
      try:
        ret['software']['fastd'] = {
          'version': lib.helper.call(['fastd', '-v'])[0].split(' ')[1],
          'enabled': True
        }
      except:
        pass

    if 'nodeinfo' in self._aliasOverlay:
      return lib.helper.merge(ret, self._aliasOverlay['nodeinfo'])
    else:
      return ret


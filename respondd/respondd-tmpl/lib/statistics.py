#!/usr/bin/env python3

import socket
import re
import sys
import json
import os

from lib.respondd import Respondd
import lib.helper


class Statistics(Respondd):
  def __init__(self, config):
    Respondd.__init__(self, config)

  def getClients(self):
    ret = {'total': 0, 'wifi': 0}

    macBridge = lib.helper.getInterfaceMAC(self._config['bridge'])

    lines = lib.helper.call(['batctl', '-m', self._config['batman'], 'tl', '-n'])
    for line in lines:
      # batman-adv -> translation-table.c -> batadv_tt_local_seq_print_text
      # R = BATADV_TT_CLIENT_ROAM
      # P = BATADV_TT_CLIENT_NOPURGE
      # N = BATADV_TT_CLIENT_NEW
      # X = BATADV_TT_CLIENT_PENDING
      # W = BATADV_TT_CLIENT_WIFI
      # I = BATADV_TT_CLIENT_ISOLA
      # . = unset
      # * c0:11:73:b2:8f:dd   -1 [.P..W.]   1.710   (0xe680a836)
      #d4:3d:7e:34:5c:b1   -1 [.P....]   0.000   (0x12a02817)
      lineMatch = re.match(r'^[\s*]*([0-9a-f:]+)\s+-\d\s\[([RPNXWI\.]+)\]', line, re.I)
      if lineMatch:
        mac = lineMatch.group(1)
        flags = lineMatch.group(2)
        if macBridge != mac and flags[0] != 'R': # Filter bridge and roaming clients
          if not mac.startswith('33:33:') and not mac.startswith('01:00:5e:'): # Filter Multicast
            ret['total'] += 1
            if flags[4] == 'W':
              ret['wifi'] += 1

    return ret

  def getTraffic(self):
    traffic = {}
    lines = lib.helper.call(['ethtool', '-S', self._config['batman']])
    if len(lines) == 0:
      return {}
    for line in lines[1:]:
      lineSplit = line.strip().split(':', 1)
      name = lineSplit[0]
      value = lineSplit[1].strip()
      traffic[name] = int(value)

    ret = {
      'tx': {
        'packets': traffic['tx'],
        'bytes': traffic['tx_bytes'],
        'dropped': traffic['tx_dropped'],
      },
      'rx': {
        'packets': traffic['rx'],
        'bytes': traffic['rx_bytes'],
      },
      'forward': {
        'packets': traffic['forward'],
        'bytes': traffic['forward_bytes'],
      },
      'mgmt_rx': {
        'packets': traffic['mgmt_rx'],
        'bytes': traffic['mgmt_rx_bytes'],
      },
      'mgmt_tx': {
        'packets': traffic['mgmt_tx'],
        'bytes': traffic['mgmt_tx_bytes'],
      },
    }

    return ret

  @staticmethod
  def getMemory():
    ret = {}
    lines = open('/proc/meminfo').readlines()
    for line in lines:
      lineSplit = line.split(' ', 1)
      name = lineSplit[0][:-1]
      value = int(lineSplit[1].strip().split(' ', 1)[0])

      if name == 'MemTotal':
        ret['total'] = value
      elif name == 'MemFree':
        ret['free'] = value
      elif name == 'Buffers':
        ret['buffers'] = value
      elif name == 'Cached':
        ret['cached'] = value

    return ret

  def getFastd(self):
    dataFastd = b''

    try:
      sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
      sock.connect(self._config['fastd_socket'])
    except socket.error as err:
      print('socket error: ', sys.stderr, err)
      return None

    while True:
      data = sock.recv(1024)
      if not data:
        break
      dataFastd += data

    sock.close()
    return json.loads(dataFastd.decode('utf-8'))

  def getMeshVPNPeers(self):
    ret = {}

    if 'fastd_socket' in self._config:
      fastd = self.getFastd()
      for peer in fastd['peers'].values():
        if peer['connection']:
          ret[peer['name']] = {
            'established': peer['connection']['established']
          }
        else:
          ret[peer['name']] = None

      return ret
    else:
      return None

  def getGateway(self):
    ret = None

    lines = lib.helper.call(['batctl', '-m', self._config['batman'], 'gwl', '-n'])
    for line in lines:
      lineMatch = re.match(r'(\*|=>)\s+([0-9a-f:]+)\s\([\d \.]+\)\s+([0-9a-f:]+)', line)
      if lineMatch:
        ret = {}
        ret['gateway'] = lineMatch.group(2)
        ret['gateway_nexthop'] = lineMatch.group(3)

    return ret

  @staticmethod
  def getRootFS():
    statFS = os.statvfs('/')
    return 1 - (statFS.f_bfree / statFS.f_blocks)

  def _get(self):
    ret = {
      'clients': self.getClients(),
      'traffic': self.getTraffic(),
      'memory': self.getMemory(),
      'rootfs_usage': round(self.getRootFS(), 4),
      'idletime': float(open('/proc/uptime').read().split(' ')[1]),
      'uptime': float(open('/proc/uptime').read().split(' ')[0]),
      'loadavg': float(open('/proc/loadavg').read().split(' ')[0]),
      'processes': dict(zip(('running', 'total'), map(int, open('/proc/loadavg').read().split(' ')[3].split('/')))),
      'mesh_vpn' : { # HopGlass-Server: node.flags.uplink = parsePeerGroup(_.get(n, 'statistics.mesh_vpn'))
        'groups': {
          'backbone': {
            'peers': self.getMeshVPNPeers()
          }
        }
      }
    }

    gateway = self.getGateway()
    if gateway != None:
      ret = lib.helper.merge(ret, gateway)

    return ret


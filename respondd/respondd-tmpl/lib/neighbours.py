#!/usr/bin/env python3

import re

from lib.respondd import Respondd
import lib.helper


class Neighbours(Respondd):
  def __init__(self, config):
    Respondd.__init__(self, config)

  @staticmethod
  def getStationDump(interfaceList):
    ret = {}

    for interface in interfaceList:
      mac = ''
      lines = lib.helper.call(['iw', 'dev', interface, 'station', 'dump'])
      for line in lines:
        # Station 32:b8:c3:86:3e:e8 (on ibss3)
        lineMatch = re.match(r'^Station ([0-9a-f:]+) \(on ([\w\d]+)\)', line, re.I)
        if lineMatch:
          mac = lineMatch.group(1)
          ret[mac] = {}
        else:
          lineMatch = re.match(r'^[\t ]+([^:]+):[\t ]+([^ ]+)', line, re.I)
          if lineMatch:
            ret[mac][lineMatch.group(1)] = lineMatch.group(2)
    return ret

  @staticmethod
  def getMeshInterfaces(batmanInterface):
    ret = {}

    lines = lib.helper.call(['batctl', 'meshif', batmanInterface, 'if'])
    for line in lines:
      lineMatch = re.match(r'^([^:]*)', line)
      interface = lineMatch.group(1)
      ret[interface] = lib.helper.getInterfaceMAC(interface)

    return ret

  def _get(self):
    ret = {'batadv': {}}

    stationDump = None

    if 'mesh-wlan' in self._config:
      ret['wifi'] = {}
      stationDump = self.getStationDump(self._config['mesh-wlan'])

    meshInterfaces = self.getMeshInterfaces(self._config['batman'])

    lines = lib.helper.call(['batctl', 'meshif', self._config['batman'], 'o', '-n'])
    for line in lines:
      # * e2:ad:db:b7:66:63    2.712s   (175) be:b7:25:4f:8f:96 [mesh-vpn-l2tp-1]
      lineMatch = re.match(r'^[ \*\t]*([0-9a-f:]+)[ ]*([\d\.]*)s[ ]*\(([ ]*\d*)\)[ ]*([0-9a-f:]+)[ ]*\[[ ]*(.*)\]', line, re.I)

      if lineMatch:
        interface = lineMatch.group(5)
        macOrigin = lineMatch.group(1)
        macNexthop = lineMatch.group(4)
        tq = lineMatch.group(3)
        lastseen = lineMatch.group(2)

        if macOrigin == macNexthop:
          if 'mesh-wlan' in self._config and interface in self._config['mesh-wlan'] and stationDump is not None:
            if meshInterfaces[interface] not in ret['wifi']:
              ret['wifi'][meshInterfaces[interface]] = {}
              ret['wifi'][meshInterfaces[interface]]['neighbours'] = {}

            if macOrigin in stationDump:
              ret['wifi'][meshInterfaces[interface]]['neighbours'][macOrigin] = {
                'signal': stationDump[macOrigin]['signal'],
                'noise': 0, # TODO: fehlt noch
                'inactive': stationDump[macOrigin]['inactive time']
              }

          if interface in meshInterfaces:
            if meshInterfaces[interface] not in ret['batadv']:
              ret['batadv'][meshInterfaces[interface]] = {}
              ret['batadv'][meshInterfaces[interface]]['neighbours'] = {}

            ret['batadv'][meshInterfaces[interface]]['neighbours'][macOrigin] = {
              'tq': int(tq),
              'lastseen': float(lastseen)
            }

    return ret


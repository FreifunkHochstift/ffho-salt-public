#!/usr/bin/env python3

import socket
import select
import struct
import json
import zlib
import time
import re
import fcntl

import lib.helper

from lib.ratelimit import rateLimit
from lib.nodeinfo import Nodeinfo
from lib.neighbours import Neighbours
from lib.statistics import Statistics

class ResponddClient:
  def __init__(self, config):
    self._config = config

    if 'rate_limit' in self._config:
      if 'rate_limit_burst' not in self._config:
        self._config['rate_limit_burst'] = 10
      self.__RateLimit = rateLimit(self._config['rate_limit'], self._config['rate_limit_burst'])
    else:
      self.__RateLimit = None

    self._nodeinfo = Nodeinfo(self._config)
    self._neighbours = Neighbours(self._config)
    self._statistics = Statistics(self._config)

    self._sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)

  @staticmethod
  def joinMCAST(sock, addr, ifname):
    group = socket.inet_pton(socket.AF_INET6, addr)
    if_idx = socket.if_nametoindex(ifname)
    sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_JOIN_GROUP, group + struct.pack('I', if_idx))

  def start(self):
    print(self._config['bridge'])
    self._sock.setsockopt(socket.SOL_SOCKET,socket.SO_BINDTODEVICE,bytes(self._config['bridge'].encode()))
    self._sock.bind(('::', self._config['port']))

    lines = lib.helper.call(['batctl', '-m', self._config['batman'], 'if'])
    for line in lines:
      lineMatch = re.match(r'^([^:]*)', line)
      self.joinMCAST(self._sock, self._config['addr'], lineMatch.group(1))

    self.joinMCAST(self._sock, self._config['addr'], self._config['bridge'])

    while True:
      msg, sourceAddress = self._sock.recvfrom(2048)

      msgSplit = str(msg, 'UTF-8').split(' ')

      responseStruct = {}
      if msgSplit[0] == 'GET': # multi_request
        for request in msgSplit[1:]:
          responseStruct[request] = self.buildStruct(request)
        self.sendStruct(sourceAddress, responseStruct, True)
      else: # single_request
        responseStruct = self.buildStruct(msgSplit[0])
        self.sendStruct(sourceAddress, responseStruct, False)

  def buildStruct(self, responseType):
    if self.__RateLimit is not None and not self.__RateLimit.limit():
      print('rate limit reached!')
      return

    responseClass = None
    if responseType == 'statistics':
      responseClass = self._statistics
    elif responseType == 'nodeinfo':
      responseClass = self._nodeinfo
    elif responseType == 'neighbours':
      responseClass = self._neighbours
    else:
      print('unknown command: ' + responseType)
      return

    return responseClass.getStruct()

  def sendStruct(self, destAddress, responseStruct, withCompression):
    if self._config['verbose'] or self._config['dry_run']:
      print('%14.3f %35s %5d: ' % (time.time(), destAddress[0], destAddress[1]), end='')
      print(json.dumps(responseStruct, sort_keys=True, indent=4))

    responseData = bytes(json.dumps(responseStruct, separators=(',', ':')), 'UTF-8')

    if withCompression:
      encoder = zlib.compressobj(zlib.Z_DEFAULT_COMPRESSION, zlib.DEFLATED, -15) # The data may be decompressed using zlib and many zlib bindings using -15 as the window size parameter.
      responseData = encoder.compress(responseData)
      responseData += encoder.flush()
      # return compress(str.encode(json.dumps(ret)))[2:-4] # bug? (mesh-announce strip here)

    if not self._config['dry_run']:
      self._sock.sendto(responseData, destAddress)


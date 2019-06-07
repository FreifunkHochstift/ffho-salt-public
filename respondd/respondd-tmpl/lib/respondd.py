#!/usr/bin/env python3

import json
import time

import lib.helper

class Respondd:
  def __init__(self, config):
    self._config = config
    self._aliasOverlay = {}
    self.__cache = {}
    self.__cacheTime = 0
    try:
      with open('alias.json', 'r') as fh: # TODO: prevent loading more then once !
        self._aliasOverlay = json.load(fh)
    except IOError:
      print('can\'t load alias.json!')
      pass

  def getNodeID(self):
    if 'nodeinfo' in self._aliasOverlay and 'node_id' in self._aliasOverlay['nodeinfo']:
      return self._aliasOverlay['nodeinfo']['node_id']
    else:
      return lib.helper.getInterfaceMAC(self._config['batman']).replace(':', '')

  def getStruct(self, rootName=None):
    if 'caching' in self._config and time.time() - self.__cacheTime <= self._config['caching']:
      ret = self.__cache
    else:
      ret = self._get()
      self.__cache = ret
      self.__cacheTime = time.time()
      ret['node_id'] = self.getNodeID()

    if rootName is not None:
      ret_tmp = ret
      ret = {}
      ret[rootName] = ret_tmp

    return ret

  @staticmethod
  def _get():
    return {}


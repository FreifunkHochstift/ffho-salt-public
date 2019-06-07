#!/usr/bin/env python3

import time

class rateLimit: # rate limit like iptables limit (per minutes)
  tLast = None

  def __init__(self, _rate_limit, _rate_burst):
    self.rate_limit = _rate_limit
    self.rate_burst = _rate_burst
    self.bucket = _rate_burst

  def limit(self):
    tNow = time.time()

    if self.tLast is None:
      self.tLast = tNow
      return True

    tDiff = tNow - self.tLast
    self.tLast = tNow

    self.bucket += (tDiff / (60 / self.rate_limit))
    if self.bucket > self.rate_burst:
      self.bucket = self.rate_burst

    if self.bucket >= 1:
      self.bucket-= 1
      return True
    else:
      return False

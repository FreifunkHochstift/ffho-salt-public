#
# HP hardware
#

/etc/modprobe.d/bnx2-blacklist.conf:
  file.managed:
    - source: salt://hardware/bnx2-blacklist.conf

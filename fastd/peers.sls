#
# FFHO Gateways specific stuff
#

# publish blacklist
/etc/fastd/peers-blacklist:
  file.managed:
    - source: salt://fastd/peers-blacklist
    - user: root
    - group: root
    - mode: 644

/etc/fastd/verify-peer.sh:
  file.managed:
    - source: salt://fastd/verify-peer.sh
    - user: root
    - group: root
    - mode: 744

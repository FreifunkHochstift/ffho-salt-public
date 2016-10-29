#
# Sysctl stuff for routers
#

include:
  - sysctl

/etc/sysctl.d/20-arp_caches.conf:
  file.managed:
    - source: salt://sysctl/arp_caches.conf
    - watch_in:
      - cmd: reload-sysctl

/etc/sysctl.d/21-ip_forward.conf:
  file.managed:
    - source: salt://sysctl/ip_forward.conf
    - watch_in:
      - cmd: reload-sysctl

/etc/sysctl.d/22-kernel.conf:
  file.managed:
    - source: salt://sysctl/kernel.conf
    - watch_in:
      - cmd: reload-sysctl

/etc/sysctl.d/NAT.conf:
  file.managed:
    - source: salt://sysctl/NAT.conf
    - watch_in:
      - cmd: reload-sysctl

/etc/sysctl.d/nf-ignore-bridge.conf:
  file.managed:
    - source: salt://sysctl/nf-ignore-bridge.conf
    - watch_in:
      - cmd: reload-sysctl

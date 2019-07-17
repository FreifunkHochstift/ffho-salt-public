#
# Networking
#

include:
  - apt
  - network.link
  - network.interfaces

network-pkg:
  pkg.installed:
    - pkgs:
      - bridge-utils
      - vlan
      - tcpdump
      - mtr-tiny
      - iperf
      - host
      - dnsutils
      - ipv6calc
    - require_in:
      - file: /etc/network/interfaces
#    - require:
#      - APT-FFHO

iproute2:
  pkg.latest


vnstat:
  pkg.installed:
    - name: vnstat
  service.running:
    - restart: True

/etc/vnstat.conf:
  file.managed:
    - source: salt://network/vnstat.conf
    - watch_in:
      - service: vnstat

# /etc/resolv.conf
/etc/resolv.conf:
  file.managed:
    - source: salt://network/resolv.conf
    - template: jinja

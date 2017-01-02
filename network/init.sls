#
# Networking
#

include:
  - apt
  - network.interfaces

network-pkg:
  pkg.installed:
    - pkgs:
      - bridge-utils
      - vlan
      - tcpdump
      - mtr-tiny
      - iperf
      - vnstat
      - host
      - dnsutils
      - ipv6calc
    - require_in:
      - file: /etc/network/interfaces
#    - require:
#      - APT-FFHO

iproute2:
  pkg.latest

# Udev rules
/etc/udev/rules.d/42-ffho-net.rules:
  file.managed:
    - template: jinja
    - source: salt://network/udev-rules.tmpl


# /etc/resolv.conf
/etc/resolv.conf:
  file.managed:
    - source: salt://network/resolv.conf

#
# Networking
#

# Which networ suite to configure?
{% set default_suite = salt['pillar.get']('network:suite', 'ifupdown-ng') %}
{% set suite = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':network:suite', default_suite) %}

include:
  - network.link
  - network.{{ suite }}
  - network.interfaces
  - network.{{ suite }}.reload

network-pkg:
  pkg.installed:
    - pkgs:
      - iproute2
      - ipv6calc
    - require_in:
      - file: /etc/network/interfaces

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
    - source:
      - salt://network/resolv.conf.H_{{ grains.id }}
      - salt://network/resolv.conf
    - template: jinja

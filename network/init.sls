#
# Networking
#

include:
  - apt

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
      - ifupdown2
      - ipv6calc
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

# Udev rules
/etc/udev/rules.d/42-ff-net.rules:
  file.managed:
    - template: jinja
    - source: salt://network/udev-rules.tmpl

# Systemd link files?
{%- set interfaces = salt['pillar.get']('netbox:interfaces') %}
{% if grains['oscodename'] == 'stretch' %}
  {% for iface in interfaces |sort %}
    {% if interfaces[iface]['mac_address'] is not none %}
/etc/systemd/network/42-{{ iface }}.link:
  file.managed:
    - source: salt://network/systemd-link.tmpl
    - template: jinja
      interface: {{ iface }}
      mac: {{ interfaces[iface]['mac_address'] }}
      desc: {{ interfaces[iface]['description'] }}
    {% endif %}
  {% endfor %}
{% endif %}

# ifupdown2 configuration
/etc/network/ifupdown2/ifupdown2.conf:
  file.managed:
    - source:
      - salt://network/ifupdown2.conf.{{ grains['oscodename'] }}
      - salt://network/ifupdown2.conf
    - require:
      - pkg: network-pkg

# /etc/resolv.conf
/etc/resolv.conf:
  file.managed:
    - source: salt://network/resolv.conf
    - template: jinja

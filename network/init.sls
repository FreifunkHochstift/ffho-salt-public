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

# Udev rules
/etc/udev/rules.d/42-ff-net.rules:
  file.managed:
    - template: jinja
    - source: salt://network/udev-rules.tmpl

# Systemd link files?
{% if grains['oscodename'] == 'stretch' %}
  {% for iface, iface_config in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':ifaces', {}).items ()|sort %}
    {% if '_udev_mac' in iface_config %}
/etc/systemd/network/42-{{ iface }}.link:
  file.managed:
    - source: salt://network/systemd-link.tmpl
    - template: jinja
      interface: {{ iface }}
      mac: {{ iface_config.get ('_udev_mac') }}
      desc: {{ iface_config.get ('desc', '') }}
    {% endif %}
  {% endfor %}
{% endif %}


# /etc/resolv.conf
/etc/resolv.conf:
  file.managed:
    - source: salt://network/resolv.conf

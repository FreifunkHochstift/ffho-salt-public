#
# DHCP server (for gateways)
#

include:
  - network.interfaces

isc-dhcp-server:
  pkg.installed:
    - name: isc-dhcp-server
  service.running:
    - enable: True
    - restart: True
    - require:
      - file: /etc/network/interfaces


/etc/dhcp/dhcpd.conf:
  file.managed:
    - source: salt://dhcp-server/dhcpd.conf
    - template: jinja
    - watch_in:
      - service: isc-dhcp-server

/etc/default/isc-dhcp-server:
  file.managed:
    - source:
      - salt://dhcp-server/dhcpd.default.{{ grains.oscodename }}
      - salt://dhcp-server/dhcpd.default
    - template: jinja
    - watch_in:
      - service: isc-dhcp-server

#
# Install dhcpd-pool monitoring magic from
# http://folk.uio.no/trondham/software/dhcpd-pool.html
/usr/local/sbin/dhcpd-pool:
  file.managed:
    - source: salt://dhcp-server/dhcpd-pool
    - mode: 755
    - user: root
    - group: root

# There's a man page. Be nice, install it.
/usr/local/share/man/man1/dhcpd-pool.1.gz:
  file.managed:
    - source: salt://dhcp-server/dhcpd-pool.1.gz
    - makedirs: true

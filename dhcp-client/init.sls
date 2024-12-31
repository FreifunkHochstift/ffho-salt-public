#
# DHCP client w/ VRF support
#

/etc/dhcp/dhclient.conf:
  file.managed:
    - source: salt://dhcp-client/dhclient.conf

/etc/dhcp/dhclient-enter-hooks.d/dont-update-resolv-conf:
  file.managed:
    - source: salt://dhcp-client/dont-update-resolv-conf
    - mode: 0755

/usr/local/sbin/dhclient-script:
  file.managed:
    - source: salt://dhcp-client/dhclient-script
    - mode: 755

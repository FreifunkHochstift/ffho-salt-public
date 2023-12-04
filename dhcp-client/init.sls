#
# DHCP client w/ VRF support
#

/etc/dhcp/dhclient.conf:
  file.managed:
    - source: salt://dhcp-client/dhclient.conf

/usr/local/sbin/dhclient-script:
  file.managed:
    - source: salt://dhcp-client/dhclient-script
    - mode: 755

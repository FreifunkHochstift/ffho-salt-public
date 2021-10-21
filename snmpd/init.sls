#
# SNMPd
#

include:
  - network
  - systemd

#
# Install and start SNMPd
# Require /etc/network/interfaces to be installed (and ifreload'ed) so we
# can simply pick lookback IP addresses from grains.
snmpd:
  pkg.installed:
    - name: snmpd
    - require:
      - file: /etc/network/interfaces
  service.running:
    - enable: true
    - restart: true

# Add dependecy on network-online.target
/etc/systemd/system/snmpd.service.d/override.conf:
  file.managed:
    - makedirs: true
    - source: salt://snmpd/service-override.conf
    - watch_in:
      - cmd: systemctl-daemon-reload

/etc/default/snmpd:
  file.managed:
    - source: salt://snmpd/default_snmpd
    - require:
      - pkg: snmpd
    - watch_in:
      - service: snmpd


/etc/snmp/snmpd.conf:
  file.managed:
    - template: jinja
    - source: salt://snmpd/snmpd.conf
    - require:
      - pkg: snmpd
    - watch_in:
      - service: snmpd

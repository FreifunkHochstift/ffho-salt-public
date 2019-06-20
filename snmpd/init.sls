#
# SNMPd
#


#
# Install and start SNMPd
# Require /etc/network/interfaces to be installed (and ifreload'ed) so we
# can simply pick lookback IP addresses from grains.
snmpd:
  pkg.installed:
    - name: snmpd
  service.running:
    - enable: true
    - restart: true


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
/etc/systemd/system/snmpd.service:
  file.managed:
    - source: salt://snmpd/snmpd.service
    - require:
      - pkg: snmpd
    - watch_in:
      - service: snmpd

/etc/snmp/ifAlias:
  file.absent

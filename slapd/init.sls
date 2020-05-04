#
# LDAP server configuration
#

slapd:
  pkg.installed:
    - name: slapd
  service.running:
    - restart: True

ldap-utils:
  pkg.installed

# Remove slapd.d config directory
/etc/ldap/slapd.d:
  file.absent

# Install proper slapd.conf
/etc/ldap/slapd.conf:
  file.managed:
    - source: salt://slapd/slapd.conf.H_{{ grains.id }}
    - watch_in:
      - service: slapd

# Listen on ldaps!
/etc/default/slapd:
  file.managed:
    - source: salt://slapd/slapd.default
    - watch_in:
      - service: slapd

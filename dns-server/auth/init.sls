#
# Authoritive FFHO DNS Server configuration (dns01/dns02 anycast)
#

include:
  - dns-server

# Bind options
/etc/bind/named.conf.options:
  file.managed:
    - source: salt://dns-server/auth/named.conf.options
    - template: jinja
    - require:
      - pkg: bind9
    - watch_in:
      - cmd: rndc-reload


# Configure authoritive zones in local config
/etc/bind/named.conf.local:
  file.managed:
    - source: salt://dns-server/auth/named.conf.local
    - require:
      - pkg: bind9
    - watch_in:
      - cmd: rndc-reload


# Copy zonefiles
/etc/bind/zones/_tree:
  file.recurse:
    - name: /etc/bind/zones
    - source: salt://dns-server/auth/zones
    - file_mode: 644
    - dir_mode: 755
    - user: root
    - group: root
    - watch_in:
      - cmd: rndc-reload

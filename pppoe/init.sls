#
# PPPoE (Vectoring-Glasfaser-Technologie!) (Salt Managed)
#

pppoe:
  pkg.installed

at:
  pkg.installed


# Generate VRF fix script and make sure it's run after session start
/etc/ppp/ip-up.local:
  file.managed:
    - source: salt://pppoe/ip-up.local
    - mode: 755
    - template: jinja

/usr/local/sbin/fix_ppp_vrf:
  file.managed:
    - source: salt://pppoe/fix_ppp_vrf
    - mode: 755


# Disable all other scripts alltogether
/etc/ppp/ip-down.local:
  file.managed:
    - source: salt://pppoe/noop.local
    - mode: 755

/etc/ppp/ipv6-up.local:
  file.managed:
    - source: salt://pppoe/noop.local
    - mode: 755

/etc/ppp/ipv6-down.local:
  file.managed:
    - source: salt://pppoe/noop.local
    - mode: 755


# Install peer config and password
/etc/ppp/peers/tkom:
  file.managed:
    - source: salt://pppoe/tkom_peer.tmpl
    - template: jinja

/etc/ppp/pap-secrets:
  file.managed:
    - source: salt://pppoe/pap-secrets
    - template: jinja

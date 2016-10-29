#
# PPPoE (Vectoring-Glasfaser-Technologie!) (Salt Managed)
#

pppoe:
  pkg.installed

/etc/ppp/ip-up.local:
  file.managed:
    - source: salt://pppoe/ip-up.local
    - mode: 755

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

/etc/ppp/peers/tkom:
  file.managed:
    - source: salt://pppoe/tkom_peer.tmpl
    - template: jinja

/etc/ppp/pap-secrets:
  file.managed:
    - source: salt://pppoe/pap-secrets
    - template: jinja

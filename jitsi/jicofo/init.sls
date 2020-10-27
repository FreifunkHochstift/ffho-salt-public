{%- from "jitsi/map.jinja" import jitsi with context %}

{% if jitsi.jicofo.enabled %}

jicofo:
  pkg.installed:
    - require:
      - pkgrepo: jitsi-repo
  service.running:
    - enable: True

### set static hostname and the like
stats.in.ffmuc.net:
  host.present:
    - ip: 10.111.0.254

/etc/jitsi/jicofo/config.json:
  file.managed:
    - source: jitsi/jicofo/config.json.jinja
    - template: jinja

/etc/jitsi/jicofo/sip-communicator.properties:
  file.managed:
    - source: jitsi/jicofo/sip-communicator.properties.jinja
    - template: jinja

{% endif %}
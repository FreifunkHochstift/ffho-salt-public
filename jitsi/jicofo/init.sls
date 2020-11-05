{%- from "jitsi/map.jinja" import jitsi with context %}

{% if jitsi.jicofo.enabled %}

include:
  - jitsi.base

jicofo:
  pkg.installed:
    - require:
      - pkgrepo: jitsi-repo
  service.running:
    - enable: True
    #- reload: True
    - watch:
      - file: /etc/jitsi/jicofo/config
      - file: /etc/jitsi/jicofo/jicofo.conf
      - file: /etc/jitsi/jicofo/sip-communicator.properties

### set static hostname and the like
stats.in.ffmuc.net:
  host.present:
    - ip: 10.111.0.254

/etc/jitsi/jicofo/config:
  file.managed:
    - source: salt://jitsi/jicofo/config.jinja
    - template: jinja

/etc/jitsi/jicofo/jicofo.conf:
  file.managed:
    - source: salt://jitsi/jicofo/jicofo.conf.jinja
    - template: jinja

/etc/jitsi/jicofo/sip-communicator.properties:
  file.managed:
    - source: salt://jitsi/jicofo/sip-communicator.properties.jinja
    - template: jinja

{% endif %}
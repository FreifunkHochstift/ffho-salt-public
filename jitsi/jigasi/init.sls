{%- from "jitsi/map.jinja" import jitsi with context %}

{% if jitsi.jigasi.enabled %}

include:
  - jitsi.base

jigasi:
  pkg.installed:
    - require:
      - pkgrepo: jitsi-repo
  service.running:
    - enable: True
    - require:
      - file: /etc/jitsi/jigasi/config
      - file: /etc/jitsi/jigasi/sip-communicator.properties
    - watch:
      - file: /etc/jitsi/jigasi/config
      - file: /etc/jitsi/jigasi/sip-communicator.properties

/etc/jitsi/jigasi/config:
  file.managed:
    - source: salt://jitsi/jigasi/config.jinja
    - template: jinja

/etc/jitsi/jigasi/sip-communicator.properties:
  file.managed:
    - source: salt://jitsi/jigasi/sip-communicator.properties.jinja
    - template: jinja
{% endif %}
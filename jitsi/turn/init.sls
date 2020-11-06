###
# Turnserver
###

coturn:
  pkg.installed:
    - name: coturn
  service.running:
    - enable: True

/etc/turnserver.conf:
  file.managed:
    - source: salt://jitsi/turn/turnserver.conf.jinja
    - template: jinja
    - require:
      - pkg: coturn
    - watch_in:
      - service: coturn
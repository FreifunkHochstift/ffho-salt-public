#
# Radvd for gateways
#

radvd:
  pkg.installed:
    - name: radvd
  service.running:
    - enable: True
    - restart: True
    - require:
      - file: /etc/radvd.conf
    - watch:
      - file: /etc/radvd.conf

/etc/radvd.conf:
  file.managed:
    - source: salt://radvd/radvd.conf
    - template: jinja

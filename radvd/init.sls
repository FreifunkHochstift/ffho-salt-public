#
# Radvd for gateways
#

{% if 'VIE01' in salt['pillar.get']('netbox:site:name') %}
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
{% else %}
radvd:
  service.dead:
    - enable: False
{% endif %}

/etc/radvd.conf:
  file.managed:
    - source: salt://radvd/radvd.conf
    - template: jinja

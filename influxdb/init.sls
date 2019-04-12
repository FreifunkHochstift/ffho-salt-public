#
# influxdb
#
{% if 'influxdb_server' in salt['pillar.get']('netbox:config_context:roles') %}

influxdb:
  pkgrepo.managed:
    - humanname: InfluxDB-Repo
    - name: deb https://repos.influxdata.com/debian stretch stable
    - key_url:  https://repos.influxdata.com/influxdb.key
    - dist: stretch
    - file: /etc/apt/sources.list.d/influxdb.list
  pkg.installed:
    - name: influxdb
    - require:
      - pkgrepo: influxdb
  service.running:
    - name: influxdb
    - enable: True
    - require:
      - pkg: influxdb
      - file: /etc/influxdb/influxdb.conf
    - watch:
      - file: /etc/influxdb/influxdb.conf
  user.present:
    - name: influxdb
    - system: True
    - groups:
      - ssl-cert
    - require:
      - pkg: influxdb

/etc/influxdb/influxdb.conf:
  file.managed:
    - source: salt://influxdb/influxdb.conf.tmpl
    - template: jinja
    - require:
      - pkg: influxdb
{% endif %}

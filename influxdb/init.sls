#
# influxdb
#
influxdb:
  pkgrepo.managed:
    - humanname: InfluxDB-Repo
    - name: deb https://repos.influxdata.com/debian buster stable
    - key_url:  https://repos.influxdata.com/influxdb.key
    - dist: buster
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

/usr/local/sbin/backup-influx.sh:
  file.managed:
    - source: salt://influxdb/backup.sh
    - mode: 700
    - user: influxdb

/etc/cron.d/backup-influx:
  file.managed:
    - contents: "0 22 * * * 	influxdb 	[ -f /usr/local/sbin/backup-influx.sh ] && /usr/local/sbin/backup-influx.sh"
    - require:
      - file: /usr/local/sbin/backup-influx.sh

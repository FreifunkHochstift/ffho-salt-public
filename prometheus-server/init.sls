#
# Set up prometheus server
#

prometheus:
  pkg.installed:
    - name: prometheus
  service.running:
    - enable: true
    - restart: true

/srv/prometheus/metrics2:
  file.directory:
    - makedirs: true
    - user: prometheus
    - group: prometheus

/etc/default/prometheus:
  file.managed:
    - source: salt://prometheus-server/prometheus.default
    - watch_in:
      - service: prometheus

/etc/prometheus/prometheus.yml:
  file.managed:
    - source: salt://prometheus-server/prometheus.yml
    - template: jinja
    - require:
      - pkg: prometheus
      - file: /srv/prometheus/metrics2
    - watch_in:
      - service: prometheus

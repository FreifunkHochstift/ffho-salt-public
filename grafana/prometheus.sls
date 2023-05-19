#
# Grafana as Prometheus front end
#

#
# Data sources
#

/etc/grafana/provisioning/datasources/prom-local.yaml:
  file.managed:
    - source: salt://grafana/datasources/prom-local.yaml.tmpl
    - template: jinja
    - require:
      - pkg: grafana
    - watch_in:
      - service: grafana-server

#
# Dashboards
#
/etc/grafana/provisioning/dashboards/FFHO.yaml:
  file.managed:
    - source: salt://grafana/dashboards/prometheus.yaml
    - require:
      - pkg: grafana
    - watch_in:
      - service: grafana-server

/var/lib/grafana/dashboards/:
  file.recurse:
    - source: salt://grafana/dashboards/prometheus/
    - file_mode: 644
    - dir_mode: 755
    - user: root
    - group: root
    - clean: True
    - require:
      - pkg: grafana
    - watch_in:
      - service: grafana-server

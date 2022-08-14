#
# Prometheus exporters to be set up
#

# All nodes get node_exporter
prometheus-node-exporter:
  pkg.installed:
    - name: prometheus-node-exporter
  service.running:
    - enable: true
    - reload: true
 
/etc/default/prometheus-node-exporter:
  file.managed:
    - source: salt://prometheus-exporters/node-exporter/prometheus-node-exporter.default
    - require:
      - pkg: prometheus-node-exporter
    - watch_in:
      - service: prometheus-node-exporter

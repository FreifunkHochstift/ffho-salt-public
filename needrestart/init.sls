#
# Needrestart
#

needrestart:
  pkg.installed

/etc/needrestart/conf.d/monitoring.conf:
  file.managed:
    - source: salt://needrestart/monitoring.conf
    - require:
      - pkg: needrestart

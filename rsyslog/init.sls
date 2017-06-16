#
# Rsyslog configuration
#

{% set roles = salt['pillar.get'] ('nodes:' ~ grains['id'] ~ ':roles') %}

rsyslog:
  pkg.installed:
    - name: rsyslog
  service.running:
    - enable: True


/etc/rsyslog-early.d:
  file.directory:
    - user: root
    - group: root
    - mode: 0755


/etc/rsyslog.conf:
  file.managed:
    - watch_in:
      - service: rsyslog
{% if 'logserver' in roles %}
    - source: salt://rsyslog/rsyslog.conf.logserver
{% else %}
    - source: salt://rsyslog/rsyslog.conf
{% endif %}

#
# Install filter rules everywhere so we have the same log layout everywhere
# and avoid logging stuff (kernel log, dhcpd, ...) multiple times (daemon.log,
# message, syslog) on every node.
#
/etc/rsyslog.d/ffho.conf:
  file.managed:
    - source: salt://rsyslog/ffho.conf
    - watch_in:
      - service: rsyslog
    - require:
      - file: /etc/rsyslog.d/ffho

/etc/rsyslog.d/ffho:
  file.recurse:
    - source: salt://rsyslog/ffho
    - file_mode: 644
    - dir_mode: 755
    - user: root
    - group: root
    - clean: true
    - watch_in:
      - service: rsyslog

/etc/logrotate.d/ffho:
  file.managed:
    - source: salt://rsyslog/ffho.logrotate


{% if 'logserver' in roles %}
/etc/rsyslog.d/99-debug.conf:
  file.managed:
    - source: salt://rsyslog/99-debug.conf
    - watch_in:
      - service: rsyslog
{% endif %}

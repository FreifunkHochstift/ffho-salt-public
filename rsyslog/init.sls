#
# Rsyslog configuration
#

{% set roles = salt['pillar.get'] ('node:roles') %}
{% set logserver = salt['pillar.get'] ('logging:syslog:logserver') %}
{% set graylog_uri = salt['pillar.get'] ('logging:graylog:syslog_uri') %}

rsyslog:
  pkg.installed:
    - name: rsyslog
  service.running:
    - enable: True


/etc/rsyslog-early.d:
  file.recurse:
    - source: salt://rsyslog/rsyslog-early.d
    - user: root
    - group: root
    - file_mode: 644
    - dir_mode: 755
    - clean: true
    - watch_in:
      - service: rsyslog


/etc/rsyslog.conf:
  file.managed:
    - watch_in:
      - service: rsyslog
{% if 'logserver' in roles %}
    - source: salt://rsyslog/rsyslog.conf.logserver
    - template: jinja
      graylog_uri: {{ graylog_uri }}
{% else %}
    - source: salt://rsyslog/rsyslog.conf
    - template: jinja
      logserver: {{ logserver }}
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
/etc/rsyslog.d/zz-debug.conf:
  file.managed:
    - source: salt://rsyslog/zz-debug.conf
    - watch_in:
      - service: rsyslog
{% endif %}

#
# Rsyslog configuration
#

{% set roles = pillar.get ('roles', []) %}

rsyslog:
  pkg.installed:
    - name: rsyslog
  service.running:
    - enable: True

/etc/rsyslog.conf:
  file.managed:
    - watch_in:
      - service: rsyslog
{% if 'logserver' in roles %}
    - source: salt://rsyslog/rsyslog.conf.logserver
{% else %}
    - source: salt://rsyslog/rsyslog.conf
{% endif %}

{% if 'logserver' in roles %}
/etc/rsyslog.d/ffho.conf:
  file.managed:
    - source: salt://rsyslog/ffho.conf

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

{% endif %}

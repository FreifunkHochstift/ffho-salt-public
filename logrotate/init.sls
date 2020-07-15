### Logrotate rules
/etc/logrotate.d/rsyslog:
  file.managed:
    - source: salt://logrotate/rsyslog

{% if grains.oscodename == "stretch" %}
/usr/lib/rsyslog/rsyslog-rotate:
  file.managed:
    - source: salt://logrotate/rsyslog-rotate
    - mode: 755
    - makedirs: True

{% endif %}

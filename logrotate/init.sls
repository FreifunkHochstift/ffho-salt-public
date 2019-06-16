### Logrotate rules
/etc/logrotate.d/rsyslog:
  file.managed:
    - source: salt://logrotate/rsyslog

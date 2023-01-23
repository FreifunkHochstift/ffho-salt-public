#
# graylog
#

{% set graylog_config = salt['pillar.get']('logging:graylog') %}
{% set mongodb_version = '5.0' %}
{% include '../mongodb/init.sls' %}

include:
  - elasticsearch

graylog-repo:
# add Graylog Repo
  pkgrepo.managed:
    - humanname: Graylog Repo
    - name: deb https://packages.graylog2.org/repo/debian/ stable 5.0
    - file: /etc/apt/sources.list.d/graylog.list
    - key_url: https://packages.graylog2.org/repo/debian/keyring.gpg

# install graylog
graylog-server:
  pkg.installed:
    - pkgs:
      - graylog-server
      - python3-ldap
    - require:
      - pkgrepo: graylog-repo
      - service: mongodb
      - service: elasticsearch
  service.running:
    - enable: True
    - require:
      - pkg: graylog-server
      - file: /etc/graylog/server/server.conf
    - watch:
      - file: /etc/graylog/server/server.conf

/etc/graylog/server/server.conf:
  file.managed:
    - source: salt://graylog/server.conf.tmpl
    - template: jinja
    - context: 
      graylog_config: {{ graylog_config }}
    - require:
      - pkg: graylog-server

# Default connection config for graylog api scripts
/etc/graylog-api-scripts.conf:
  file.managed:
    - source: salt://graylog/graylog-api-scripts.conf.tmpl
    - mode: 600
    - template: jinja
    - context:
      graylog_config: {{ graylog_config }}

# Install cronjob and notification script
/etc/cron.d/graylog-system-notifications:
  file.managed:
    - source: salt://graylog/graylog-system-notifications.cron

/usr/local/sbin/graylog-system-notifications:
  file.managed:
    - source: salt://graylog/graylog-system-notifications
    - mode: 700
    - template: jinja
    - context:
      graylog_config: {{ graylog_config }}

# Install cronjob, group mapping script and config files
/etc/graylog-group-mapping.conf:
  file.managed:
    - source: salt://graylog/graylog-group-mapping.conf.tmpl
    - mode: 600
    - template: jinja
    - context:
      graylog_config: {{ graylog_config }}

/etc/cron.d/graylog-group-mapping:
  file.managed:
    - source: salt://graylog/graylog-group-mapping.cron

/usr/local/sbin/graylog-group-mapping:
  file.managed:
    - source: salt://graylog/graylog-group-mapping
    - mode: 700
    - template: jinja
    - context:
      graylog_config: {{ graylog_config }}

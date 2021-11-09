#
# graylog
#

{% set graylog_config = salt['pillar.get']('logging:graylog') %}

include:
  - mongodb
  - elasticsearch

graylog-repo:
# add Graylog Repo
  pkgrepo.managed:
    - humanname: Graylog Repo
    - name: deb https://packages.graylog2.org/repo/debian/ stable 4.2
    - file: /etc/apt/sources.list.d/graylog.list
    - key_url: https://packages.graylog2.org/repo/debian/keyring.gpg

# install graylog
graylog-server:
  pkg.installed:
    - pkgs:
      - graylog-server
      - graylog-enterprise-plugins
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
      graylog_config: {{graylog_config}}
    - require:
      - pkg: graylog-server

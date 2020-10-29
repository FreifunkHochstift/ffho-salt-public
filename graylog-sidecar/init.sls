
{% if grains.osfullname in 'Raspbian' %}
graylog-sidecar-pkg:
  pkg.installed:
    - sources:
      - graylog-sidecar: https://github.com/Graylog2/collector-sidecar/releases/download/1.0.2/graylog-sidecar_1.0.2-1_armv7.deb
      - filebeat: https://apt.ffmuc.net/filebeat-oss-8.0.0-SNAPSHOT-armhf.deb

{% else %}{# if grains.osfullname in 'Raspbian' #}

graylog-repo:
    pkgrepo.managed:
    - humanname: Graylog-Repo
    - name: deb https://packages.graylog2.org/repo/debian/ sidecar-stable 1.0
    - key_url:  https://packages.graylog2.org/repo/debian/pubkey.gpg
    - file: /etc/apt/sources.list.d/graylog-sidecar.list

filebeat-repo:
  pkgrepo.managed:
    - humanname: Elastic-Repo
    - name: deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main
    - key_url:  https://artifacts.elastic.co/GPG-KEY-elasticsearch
    - file: /etc/apt/sources.list.d/elastic-7.x.list

{% endif %}

graylog-sidecar:
  pkg.installed

filebeat:
  pkg.installed

{% if not salt['file.file_exists']('/etc/systemd/system/graylog-sidecar.service') %}
graylog-sidecar-install-service:
  cmd.run:
    - name: "graylog-sidecar -service install"
    - onchanges:
      - pkg: graylog-sidecar
{% endif %}

graylog-sidecar-config:
  file.managed:
    - name: /etc/graylog/sidecar/sidecar.yml
    - source: salt://graylog-sidecar/sidecar.yml
    - template: jinja
    - require:
      - pkg: graylog-sidecar

graylog-sidecar-service:
  service.running:
    - name: graylog-sidecar
    - enable: true
    - require:
      - pkg: graylog-sidecar
      - file: graylog-sidecar-config
    - watch:
      - pkg: graylog-sidecar
      - file: graylog-sidecar-config

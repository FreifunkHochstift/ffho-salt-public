graylog-sidecar-pkg:
{% if grains.osfullname in 'Raspbian' %}
  pkg.installed:
    - sources:
      - graylog-sidecar: https://github.com/Graylog2/collector-sidecar/releases/download/1.0.2/graylog-sidecar_1.0.2-1_armv7.deb
      - filebeat: https://apt.ffmuc.net/filebeat-oss-8.0.0-SNAPSHOT-armhf.deb
{% else %}
  pkg.installed:
    - sources:
      - graylog-sidecar: https://github.com/Graylog2/collector-sidecar/releases/download/1.0.2/graylog-sidecar_1.0.2-1_amd64.deb
      - filebeat: https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.9.3-amd64.deb
{% endif %}

{% if not salt['file.file_exists']('/etc/systemd/system/graylog-sidecar.service') %}
graylog-sidecar-install-service:
  cmd.run:
    - name: "graylog-sidecar -service install"
    - onchanges:
      - pkg: graylog-sidecar-pkg
{% endif %}

graylog-sidecar-config:
  file.managed:
    - name: /etc/graylog/sidecar/sidecar.yml
    - source: salt://graylog-sidecar/sidecar.yml
    - template: jinja
    - require:
      - pkg: graylog-sidecar-pkg

graylog-sidecar-service:
  service.running:
    - name: graylog-sidecar
    - enable: true
    - watch:
      - pkg: graylog-sidecar-pkg
      - file: graylog-sidecar-config 

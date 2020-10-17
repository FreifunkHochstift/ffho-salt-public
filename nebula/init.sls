###
# nebula
###

{% if "nebula" in salt["pillar.get"]("netbox:config_context", {}) %}
{% set nebula_version = salt["pillar.get"]("netbox:config_context:nebula:version", "1.3.0") %}
nebula-tmp-bin:
  archive.extracted:
    - name: /var/cache/salt/nebula
    - if_missing: /usr/local/bin/nebula
    {% if grains.osarch == "armhf" %}
    - source: https://github.com/slackhq/nebula/releases/download/v{{ nebula_version }}/nebula-linux-arm-7.tar.gz
    {% else %}
    - source: https://github.com/slackhq/nebula/releases/download/v{{ nebula_version }}/nebula-linux-{{ grains.osarch }}.tar.gz
    {% endif %}
    - makedirs: True
    - archive_format: tar
    - user: root
    - group: root
    - mode: 755
    - skip_verify: True
    - enforce_toplevel: False

nebula-symlink:
  file.symlink:
    - name:   /usr/local/bin/nebula
    - target: /var/cache/salt/nebula/nebula
    - user: root
    - group: root
    - force: True # for migration where it was a file instead of a symlink
    - require:
        - archive: nebula-tmp-bin

/etc/nebula/ca.crt:
  file.managed:
    - source: salt://nebula/cert/ca-ffmuc.crt

/etc/nebula/{{ grains['id'] }}.crt:
  file.managed:
    - source: salt://nebula/cert/{{ grains['id'] }}.crt
    - makedirs: True
    - user: root
    - group: root
    - mode: 644

/etc/nebula/{{ grains['id'] }}.key:
  file.managed:
    - source: salt://nebula/cert/{{ grains['id'] }}.key
    - makedirs: True
    - user: root
    - group: root
    - mode: 640

/etc/nebula/config.yml:
  file.managed:
    - source:
        - salt://nebula/files/{{ grains['id'] }}-config.yml.jinja
        - salt://nebula/files/config.yml.jinja
    - makedirs: True
    - template: jinja
    - user: root
    - group: root
    - mode: 644

systemd-reload:
  cmd.run:
   - name: systemctl --system daemon-reload
   - onchanges:  
     - file: nebula-service-file

nebula-service-file:
  file.managed:
    - source: salt://nebula/files/nebula.service
    - name: /etc/systemd/system/nebula.service

nebula-service:
  service.running:
    - enable: True
    - running: True
    - reload: True
    - name: nebula
    - require:
        - file: nebula-service-file
        - file: /etc/nebula/config.yml
        - file: /etc/nebula/{{ grains['id'] }}.crt
        - file: /etc/nebula/{{ grains['id'] }}.key
        - file: nebula-symlink
    - watch:
        - file: /etc/nebula/config.yml

{% endif %}
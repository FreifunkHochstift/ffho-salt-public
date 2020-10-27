###
# nebula
###

{% if "nebula-meet" in salt["pillar.get"]("netbox:config_context", {}) %}
include:
  - nebula.install

/etc/nebula/meet-ca.crt:
  file.managed:
    - source: salt://nebula/cert-meet/ca.crt
    - require:
        - file: /etc/nebula/meet-config.yml

/etc/nebula/meet-{{ grains['id'] }}.crt:
  file.managed:
    - source: salt://nebula/cert-meet/{{ grains['id'] }}.crt
    - makedirs: True
    - user: root
    - group: root
    - mode: 644

/etc/nebula/meet-{{ grains['id'] }}.key:
  file.managed:
    - source: salt://nebula/cert-meet/{{ grains['id'] }}.key
    - makedirs: True
    - user: root
    - group: root
    - mode: 640

/etc/nebula/meet-config.yml:
  file.managed:
    - source:
        - salt://nebula/files/{{ grains['id'] }}-config-meet.yml.jinja
        - salt://nebula/files/meet-config.yml.jinja
    - makedirs: True
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
        - file: /etc/nebula/meet-{{ grains['id'] }}.crt

systemd-reload-nebula-meet:
  cmd.run:
   - name: systemctl --system daemon-reload
   - onchanges:  
     - file: nebula-meet-service-file

nebula-meet-service-file:
  file.managed:
    - source: salt://nebula/files/meet-nebula.service
    - name: /etc/systemd/system/nebula-meet.service
    - require:
        - file: /etc/nebula/meet-{{ grains['id'] }}.crt

nebula-meet-service:
  service.running:
    - enable: True
    - running: True
    - reload: True
    - name: nebula-meet
    - require:
        - file: nebula-meet-service-file
        - file: /etc/nebula/meet-config.yml
        - file: /etc/nebula/meet-{{ grains['id'] }}.crt
        - file: /etc/nebula/meet-{{ grains['id'] }}.key
        - file: nebula-symlink
    - watch:
        - file: /etc/nebula/meet-config.yml

{% endif %}

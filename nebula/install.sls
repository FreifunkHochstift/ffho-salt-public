###
# install nebula
###

{%- from "nebula/map.jinja" import nebula with context %}

nebula-tmp-bin:
  archive.extracted:
    - name: /var/cache/salt/nebula
    - if_missing: /usr/local/bin/nebula
    {% if grains.osarch == "armhf" %}
    - source: https://github.com/slackhq/nebula/releases/download/v{{ nebula.version }}/nebula-linux-arm-7.tar.gz
    {% else %}
    - source: https://github.com/slackhq/nebula/releases/download/v{{ nebula.version }}/nebula-linux-{{ grains.osarch }}.tar.gz
    {% endif %}
    - makedirs: True
    - archive_format: tar
    - user: root
    - group: root
    - mode: 755
    - skip_verify: True
    - enforce_toplevel: False

nebula-binary:
  file.copy:
    - name:   /usr/local/bin/nebula
    - source: /var/cache/salt/nebula/nebula
    - user: root
    - group: root
    - require:
        - archive: nebula-tmp-bin

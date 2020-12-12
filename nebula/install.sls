###
# install nebula
###

{%- from "nebula/map.jinja" import nebula with context %}

nebula-tmp-bin:
  archive.extracted:
    - name: /tmp/nebula
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
  file.managed:
    - name:  /usr/local/bin/nebula
{% if salt['file.file_exists' ]('/tmp/nebula/nebula') %}
    - source: /tmp/nebula/nebula
{% endif %}
    - user: root
    - group: root
    - mode: 0755
    - require:
        - archive: nebula-tmp-bin

#
# Docker containers
#

{% if 'docker' in salt["pillar.get"]('netbox:config_context') %}
{% set containers = salt["pillar.get"]('netbox:config_context:docker')   %}
{% for container in containers  %}

directory-{{ containers[container]['container_dir'] }}:
  file.directory:
    - name: {{ containers[container]['container_dir'] }}
    - user: root
    - group: root
    - makedirs: True
    - dir_mode: 755
{% if 'git' in containers[container] %}
git-{{ container }}:
  git.cloned:
    - name: {{ containers[container]['git'] }}
    - target: {{ containers[container]['container_dir'] }}

git-update-{{ container }}:
  git.latest:
    - name: {{ containers[container]['git'] }}
    - target: {{ containers[container]['container_dir'] }}
    - require:
      - file: directory-{{ containers[container]['container_dir'] }}
      - git: git-{{ container }}
{% endif %}

{% if 'mounts' in containers[container] %}
{% for mount in containers[container]['mounts'] %}
{% if not salt['file.directory_exists' ](mount) %}
mounts-{{ mount }}:
  file.directory:
    - name: {{ mount }}
    - user: root
    - group: root
    - makedirs: True
    - dir_mode: 757
{% endif  %}
{% endfor %}
{% endif  %}

{% if 'files' in containers[container] %}
{% for file in containers[container]['files'] %}
{% if not salt['file.file_exists' ](file) %}
files-{{ file  }}:
  file.managed:
    - name: {{ file }}
    - source: salt://docker-containers/{{ file | regex_replace('(.*\/)','')  }}
    - user: root
    - group: root
    - makedirs: True
    - dir_mode: 757
{% endif  %}
{% endfor %}
{% endif  %}

compose-file-{{ container }}:
  file.managed:
    - name: {{ containers[container]['container_dir'] }}/{{ container }}-compose.yml
    - source: salt://docker-containers/{{ container }}-compose.yml
    - template: jinja
    - user: root
    - group: root
    - mode: 600
    {%- if 'credentials' in containers[container] %}
    - context:
      credentials: {{ containers[container]['credentials'] }}
    {% endif  %}

compose-build-{{ container }}:
  module.run:
    - name: dockercompose.build 
    - path: {{ containers[container]['container_dir'] }}/{{ container }}-compose.yml
    - require:
      - file: compose-file-{{ container }}
compose-start-{{ container }}:
  module.run:
    - name: dockercompose.up
    - path: {{ containers[container]['container_dir'] }}/{{ container }}-compose.yml
{% endfor %}
{% endif %}


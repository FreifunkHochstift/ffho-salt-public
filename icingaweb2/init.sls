#
# Icingaweb2
#
{% set roles = salt['pillar.get']('node:roles', []) %}
{% set icingaweb2_config = salt['pillar.get']('monitoring:icingaweb2') %}

include:
  - apt
  - sudo
  - needrestart
  - icinga2

# Install icingaweb2 package
icingaweb2-pkgs:
  pkg.installed:
    - pkgs:
      - icingaweb2
      - icinga2-ido-mysql
    - require:
      - file: /etc/apt/sources.list.d/icinga.list

# Install monitoring module configs
monitoring-module:
  file.recurse:
    - name: /etc/icingaweb2/modules/monitoring/
    - source: salt://icingaweb2/modules/monitoring/
    - file_mode: 660
    - dir_mode: 2770
    - user: www-data
    - group: icingaweb2

/etc/icingaweb2/authentication.ini:
  file.managed:
    - source: salt://icingaweb2/authentication.ini.tmpl
    - mode: 660
    - user: www-data
    - group: icingaweb2
    - template: jinja
    - context: 
      icingaweb2_config: {{ icingaweb2_config }}
    - require:
      - pkg: icingaweb2-pkgs

/etc/icingaweb2/roles.ini:
  file.managed:
    - source: salt://icingaweb2/roles.ini.tmpl
    - mode: 660
    - user: www-data
    - group: icingaweb2
    - template: jinja
    - context: 
      icingaweb2_config: {{ icingaweb2_config }}
    - require:
      - pkg: icingaweb2-pkgs

/etc/icingaweb2/groups.ini:
  file.managed:
    - source: salt://icingaweb2/groups.ini.tmpl
    - mode: 660
    - user: www-data
    - group: icingaweb2
    - template: jinja
    - context: 
      icingaweb2_config: {{ icingaweb2_config }}
    - require:
      - pkg: icingaweb2-pkgs

/etc/icingaweb2/resources.ini:
  file.managed:
    - source: salt://icingaweb2/resources.ini.tmpl
    - mode: 660
    - user: www-data
    - group: icingaweb2
    - template: jinja
    - context: 
      icingaweb2_config: {{ icingaweb2_config }}
    - require:
      - pkg: icingaweb2-pkgs

/etc/icingaweb2/navigation/menu.ini:
  file.managed:
    - source: salt://icingaweb2/menu.ini.tmpl
    - mode: 660
    - user: www-data
    - group: icingaweb2
    - template: jinja
    - context: 
      icingaweb2_config: {{ icingaweb2_config }}
    - require:
      - pkg: icingaweb2-pkgs


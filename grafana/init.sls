#
# grafana
#

{% set grafana_cfg = salt['pillar.get']('grafana') %}

{% set node_config = salt['pillar.get']('nodes:' ~ grains['id']) %}


grafana:
# add Grafana Repo
  file.managed:
    - names:
      - /usr/share/keyrings/grafana.key:
        - source: salt://grafana/grafana.key
      - /etc/apt/sources.list.d/grafana.list:
        - source: salt://grafana/grafana.list.tmpl
        - template: jinja
        - require:
          - file: /usr/share/keyrings/grafana.key

# install grafana
  pkg.installed:
    - name: grafana
    - require:
      - file: /etc/apt/sources.list.d/grafana.list

  service.running:
    - name: grafana-server
    - enable: True
    - require:
      - pkg: grafana
      - file: /etc/grafana/grafana.ini
      - file: /etc/grafana/ldap.toml
      - user: grafana
    - watch:
      - file: /etc/grafana/grafana.ini
      - file: /etc/grafana/ldap.toml

# add user 'grafana' to group 'ssl-cert' to access ssl-key file
  user.present:
    - name: grafana
    - system: True
    - groups:
      - ssl-cert
    - require:
      - pkg: grafana

/etc/grafana/grafana.ini:
  file.managed:
    - source: salt://grafana/grafana.ini.tmpl
    - template: jinja
      config: {{ grafana_cfg }}
    - require:
      - pkg: grafana


/etc/grafana/ldap.toml:
{% if 'ldap' in grafana_cfg %}
  file.managed:
    - source: salt://grafana/ldap.toml.tmpl
    - template: jinja
      config: {{ grafana_cfg.ldap }}
{% else %}
  file.absent:
{% endif %}
    - require:
      - pkg: grafana

#
# Plugins

# Grafana-Piechart-Panel
grafana-piechart:
  cmd.run:
    - name: grafana-cli plugins install grafana-piechart-panel
    - creates: /var/lib/grafana/plugins/grafana-piechart-panel
    - watch_in:
      - service: grafana

grafana-imagerenderer-deps:
  pkg.installed:
    - pkgs:
      - libxdamage1 
      - libxext6 
      - libxi6 
      - libxtst6 
      - libnss3 
      - libnss3 
      - libcups2 
      - libxss1 
      - libxrandr2 
      - libasound2 
      - libatk1.0-0 
      - libatk-bridge2.0-0 
      - libpangocairo-1.0-0 
      - libpango-1.0-0 
      - libcairo2 
      - libatspi2.0-0 
      - libgtk3.0-cil 
      - libgdk3.0-cil 
      - libx11-xcb-dev

grafana-imagerenderer:
  cmd.run:
    - name: grafana-cli plugins install grafana-image-renderer
    - creates: /var/lib/grafana/plugins/grafana-image-renderer
    - watch_in:
      - service: grafana
    - require:
      - pkg: grafana-imagerenderer-deps

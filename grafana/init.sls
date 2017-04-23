#
# grafana
#

{% set node_config = salt['pillar.get']('nodes:' ~ grains['id']) %}

grafana:
# add Grafana Repo
  pkgrepo.managed:
    - humanname: Grafana Repo
    - name: deb https://packagecloud.io/grafana/stable/debian/ jessie main
    - file: /etc/apt/sources.list.d/grafana.list
    - key_url: https://packagecloud.io/grafana/stable/gpgkey
# install grafana
  pkg.installed:
    - name: grafana
    - require:
      - pkgrepo: grafana
      - pkgrepo: grafana-src
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

# add Grafana src-Repo
grafana-src:
  pkgrepo.managed:
    - humanname: Grafana Repo
    - name: deb-src https://packagecloud.io/grafana/stable/debian/ jessie main
    - file: /etc/apt/sources.list.d/grafana.list
    - key_url: https://packagecloud.io/grafana/stable/gpgkey

# copy custom config
/etc/grafana/grafana.ini:
  file.managed:
    - source: salt://grafana/grafana.ini.tmpl
    - template: jinja
      config: {{node_config.grafana}}
    - require:
      - pkg: grafana

# copy LDAP config
/etc/grafana/ldap.toml:
{% if 'ldap' in node_config.grafana %}
  file.managed:
    - source: salt://grafana/ldap.toml.tmpl
    - template: jinja
      config: {{node_config.grafana.ldap}}
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

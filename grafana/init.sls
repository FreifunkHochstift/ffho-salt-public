#
# grafana
#
{% if 'grafana_server' in salt['pillar.get']('netbox:config_context:roles') %}

grafana:
# add Grafana Repo
  pkgrepo.managed:
    - humanname: Grafana Repo
    - name: deb https://packages.grafana.com/oss/deb stable main
    - file: /etc/apt/sources.list.d/grafana.list
    - key_url: https://packages.grafana.com/gpg.key
# install grafana
  pkg.installed:
    - name: grafana
    - require:
      - pkgrepo: grafana
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

# copy custom config
/etc/grafana/grafana.ini:
  file.managed:
    - source: salt://grafana/grafana.ini.tmpl
    - template: jinja
    - require:
      - pkg: grafana

# copy LDAP config
/etc/grafana/ldap.toml:
  file.managed:
    - source: salt://grafana/ldap.toml.tmpl
    - template: jinja
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
{% endif %}

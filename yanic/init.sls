#
# yanic
#

# add yanic directory
/srv/yanic/data:
  file.directory:
    - makedirs: True

# copy yanic binary to destination
# the binary needs to be provided by the salt-master
yanic:
  pkg.installed:
    - sources:
      - yanic: http://apt.ffmuc.net/yanic-0.0.2-17.deb

# copy systemd yanic@.service
/etc/systemd/system/yanic@.service:
  file.managed:
    - source: salt://yanic/yanic@.service
    - require:
      - file: yanic

# the internal webserver should be enabled
{% set webserver = "true" %}

# get loopback IPv6 for binding the webserver to it
{% set node_config = salt['pillar.get']('nodes:' ~ grains['id']) %}
{% set bind_ip = salt['ffho_net.get_loopback_ip'](node_config, grains['id'], 'v6') %}

# for each site
{% for site in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':sites', []) %}
# add webserver directory
/srv/yanic/data/{{site}}:
  file.directory:
    - require:
      - file: /srv/yanic/data

# add configuration file
/srv/yanic/{{site}}.conf:
  file.managed:
    - source: salt://yanic/yanic.conf.tmpl
    - template: jinja
    - defaults:
      iface: "br-{{site}}"
      site: "{{site}}"
      webserver: "{{webserver}}"
      bind_ip: {{bind_ip}}
      influxdb: {{node_config.yanic.influxdb}}
  # the webserver should only be enabled once
  {% set webserver = "false" %}
    - require:
      - file: /srv/yanic/data/{{site}}

# enable the yanic service
# and restart if configuration or binary has changed
yanic@{{site}}:
  service.running:
    - enable: True
    - require:
      - file: /srv/yanic/{{site}}.conf
      - file: /etc/systemd/system/yanic@.service
    - watch:
      - file: /srv/yanic/{{site}}.conf
      - file: yanic
{% endfor %}


/usr/local/bin/ff_merge_nodes_json:
  file.managed:
    - source: salt://yanic/ff_merge_nodes_json
    - mode: 755

/etc/cron.d/ff_merge_nodes_json:
  file.managed:
    - source: salt://yanic/ff_merge_nodes_json.cron

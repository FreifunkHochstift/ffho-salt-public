/srv/ffho-respondd:
  file.directory

ffho-respondd:
  pkg.installed:
    - pkgs:
      - git
      - lsb-release
      - ethtool
      - python3
      - python3-netifaces
  git.latest:
   - name: https://github.com/FreifunkHochstift/ffho-respondd.git
   - target: /srv/ffho-respondd
   - require:
     - file: /srv/ffho-respondd

/etc/systemd/system/respondd@.service:
  file.managed:
    - source: salt://respondd/respondd@.service
    - require:
      - git: ffho-respondd

{%- set node_config = salt['pillar.get']('nodes:' ~ grains['id'], {}) %}
{%- set sites_config = salt['pillar.get']('sites', {}) %}

{%- set ifaces = salt['ffho_net.get_interface_config'](node_config, sites_config) %}
{% set device_no = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':id', -1) %}
{% for site in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':sites', []) %}
  {% set site_no = salt['pillar.get']('sites:' ~ site ~ ':site_no') %}
  {% set mac_address = salt['ffho_net.gen_batman_iface_mac'](site_no, device_no, 'dummy') %}

/srv/ffho-respondd/{{site}}.conf:
  file.managed:
    - source: salt://respondd/respondd-config.tmpl
    - template: jinja
    - defaults:
      mac_address: {{ mac_address }}
    {% if 'batman_ext' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
      bat_iface: "bat-{{site}}-ext"
    {% else %}
      bat_iface: "bat-{{site}}"
    {% endif %}
    {% if 'fastd_peers' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
      fastd_peers: "true"
    {% else %}
      fastd_peers: "false"
    {% endif %}
    {% if salt['pillar.get']('nodes:' ~ grains['id'] ~ ':sites', [])|length > 1 %}
      hostname: "{{grains['id'].split('.')[0]}}-{{site}}"
    {% else %}
      hostname: "{{grains['id'].split('.')[0]}}"
    {% endif %}
    {% if 'br-' ~ site in ifaces %}
      mcast_iface: "br-{{site}}"
    {% else %}
      mcast_iface: "bat-{{site}}"
    {% endif %}
      site: {{site}}
      site_code: "{{salt['pillar.get']('nodes:' ~ grains['id'] ~ ':site_code', '')}}"
      location: {{salt['pillar.get']('nodes:' ~ grains['id'] ~ ':location', {})}}
    - require:
      - git: ffho-respondd

respondd@{{site}}:
  service.running:
    - enable: True
    - require:
      - file: /srv/ffho-respondd/{{site}}.conf
      - file: /etc/systemd/system/respondd@.service
    - watch:
      - file: /srv/ffho-respondd/{{site}}.conf
      - git: ffho-respondd
{% endfor %}

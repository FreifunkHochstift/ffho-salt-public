#
# respondd
#

{% set sites_all = pillar.get ('sites') %}
{% set sites_node = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':sites', []) %}

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
   - name: https://git.ffho.net/FreifunkHochstift/ffho-respondd.git
   - force_fetch: True
   - target: /srv/ffho-respondd
   - require:
     - file: /srv/ffho-respondd

/etc/systemd/system/respondd@.service:
  file.managed:
    - source: salt://respondd/respondd@.service
    - require:
      - git: ffho-respondd

{% set node_config = salt['pillar.get']('nodes:' ~ grains['id'], {}) %}
{% set sites_config = salt['pillar.get']('sites', {}) %}

{% set ifaces = salt['ffho_net.get_interface_config'](node_config, sites_config) %}
{% set device_no = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':id', -1) %}
{% for site in sites_node %}
  {% set site_no = salt['pillar.get']('sites:' ~ site ~ ':site_no') %}
  {% set mac_address = salt['ffho_net.gen_batman_iface_mac'](site_no, device_no, 'bat') %}
  {% set region_code = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':location:region:code', salt['pillar.get']('nodes:' ~ grains['id'] ~ ':site_code', '')) %}

/srv/ffho-respondd/{{site}}.conf:
  file.managed:
    - source: salt://respondd/respondd-config.tmpl
    - template: jinja
    - defaults:
      bat_iface: "bat-{{site}}"
      fastd_peers: "{% if 'fastd_peers' in node_config.get ('roles', []) %}true{% else %}false{% endif %}"
      hostname: "{{ grains['id'].split('.')[0] }}{% if node_config.get ('sites', [])|length > 1 or grains.id.startswith('gw') %}-{{site}}{% endif %}"
      mcast_iface: {% if 'br-' ~ site in ifaces %}"br-{{site}}"{% else %}"bat-{{site}}"{% endif %}
    {% if 'fastd' in node_config.get ('roles', []) %}
      mesh_vpn: [{{ site }}_intergw, {{ site }}_nodes4, {{ site }}_nodes6]
    {% else %}
      mesh_vpn: False
    {% endif %}
      site: {{ site }}
      site_code: "{{ region_code }}"
      location: {{ node_config.get('location', {}) }}
      location_hidden: {{ 'location-hidden' in node_config.get ('tags', []) }}
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

{% if 'batman_ext' in node_config.get('roles', []) %}
/srv/ffho-respondd/{{site}}-ext.conf:
  file.managed:
    - source: salt://respondd/respondd-config.tmpl
    - template: jinja
    - defaults:
      bat_iface: "bat-{{site}}-ext"
      fastd_peers: "{% if 'fastd_peers' in node_confi.get ('roles', []) %}true{% else %}false{% endif %}"
      hostname: "{{ grains['id'].split('.')[0] }}{% if node_config.get ('sites', [])|length > 1 or grains.id.startswith('gw') %}-{{site}}{% endif %}-ext"
      mcast_iface: "bat-{{ site }}-ext"
    {% if 'fastd' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
      mesh_vpn: [{{ site }}_intergw, {{ site }}_nodes4, {{ site }}_nodes6]
    {% else %}
      mesh_vpn: False
    {% endif %}
      site: {{site}}
      site_code: "{{ node_config.get ('site_code', '') }}"
      location: {{ node_config.get ('location', {}) }}
    - require:
      - git: ffho-respondd

respondd@{{site}}-ext:
  service.running:
    - enable: True
    - require:
      - file: /srv/ffho-respondd/{{site}}-ext.conf
      - file: /etc/systemd/system/respondd@.service
    - watch:
      - file: /srv/ffho-respondd/{{site}}-ext.conf
      - git: ffho-respondd
{% else %}
/srv/ffho-respondd/{{ site }}-ext.conf:
  file.absent

respondd@{{ site }}-ext:
  service.dead:
    - enable: False
    - prereq:
      - file: /srv/ffho-respondd/{{ site }}-ext.conf
{% endif %}
{% endfor %}

#
# Cleanup configurations for previosly configured instances.
{% for site in sites_all if site not in sites_node %}
Cleanup /srv/ffho-respondd/{{site}}.conf:
  file.absent:
    - name: /srv/ffho-respondd/{{site}}.conf

Cleanup /srv/ffho-respondd/{{site}}-ext.conf:
  file.absent:
    - name: /srv/ffho-respondd/{{site}}-ext.conf

# stop respondd service
Stop respondd@{{site}}:
  service.dead:
    - name: respondd@{{site}}
    - enable: False
    - prereq:
      - file: Cleanup /srv/ffho-respondd/{{site}}.conf

Stop respondd@{{site}}-ext:
  service.dead:
    - name: respondd@{{site}}-ext
    - enable: False
    - prereq:
      - file: Cleanup /srv/ffho-respondd/{{site}}-ext.conf
{% endfor %}

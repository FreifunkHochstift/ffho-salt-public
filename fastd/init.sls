#
# Fastd for gateways
#

{% set sites_all = pillar.get ('sites') %}
{% set sites_node = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':sites', {}) %}
{% set device_no = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':id', -1) %}

include:
  - network.interfaces
{% if 'fastd_peers' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
  - fastd.peers
{% endif %}


fastd-repo:
  pkgrepo.managed:
    - human_name: Neoraiders fastd repository
    - name: deb http://repo.universe-factory.net/debian/ sid main
    - dist: sid
    - file: /etc/apt/sources.list.d/fastd.list
    - keyserver: keyserver.ubuntu.com
    - keyid: CB201D9C


# Install fastd (after fastd-repo and the network are configured)
fastd:
  pkg.installed:
    - name: fastd
    - require:
      - pkgrepo: fastd-repo
      - sls: network.interfaces
  service.dead:
    - enable: False

/etc/systemd/system/fastd@.service:
  file.managed:
    - source: salt://fastd/fastd@.service

/etc/fastd:
  file.directory:
    - user: root
    - group: root
    - mode: 711
  require:
    - pkg: fastd

#
# Set up fastd configuration for every network (nodes4, nodes6, intergw-vpn)
# for every site associated for the current minion ID.
#
{% for site in sites_node %}
  {% set site_no = salt['pillar.get']('sites:' ~ site ~ ':site_no') %}

  {% set networks = ['intergw'] %}
  {% if 'fastd_peers' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
    {% do networks.extend (['nodes4', 'nodes6']) %}
  {% endif %}

  {% for network in networks %}
    {% set network_type = 'nodes' if network.startswith ('nodes') else network %}
    {% set instance_name = site ~ '_' ~ network %}
    {% set mac_address = salt['ffho_net.gen_batman_iface_mac'](site_no, device_no, network) %}

/etc/fastd/{{ instance_name }}:
  file.directory:
     - makedirs: true
     - mode: 755
     - require:
       - file: /etc/fastd

/etc/fastd/{{ instance_name }}/fastd.conf:
  file.managed:
    - source: salt://fastd/fastd.conf
    - template: jinja
      network: {{ network }}
      network_type: {{ network_type }}
      site: {{ site }}
      site_no: {{ site_no }}
      mac_address: {{ mac_address }}
    {% if 'batman_ext' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
      bat_iface: bat-{{ site }}-ext
    {% else %}
      bat_iface: bat-{{ site }}
    {% endif %}
      peer_limit: {{ salt['pillar.get']('nodes:' ~ grains['id'] ~ ':fastd:peer_limit', False) }}
    - require:
      - file: /etc/fastd/{{ instance_name }}
    - watch_in:
  
/etc/fastd/{{ instance_name }}/secret.conf:
  file.managed:
    - source: salt://fastd/secret.conf.tmpl
    - template: jinja
      secret: {{ salt['pillar.get']('nodes:' ~ grains['id'] ~ ':fastd:' ~ network_type + '_privkey') }}
    - mode: 600
    - user: root
    - group: root
    - require:
      - file: /etc/fastd/{{ instance_name }}


# Create systemd start link
fastd@{{ instance_name }}:
  service.running:
    - enable: True
    - reload: True
    - require:
      - file: /etc/systemd/system/fastd@.service
      - file: /etc/fastd/{{ instance_name }}/fastd.conf
      - file: /etc/fastd/{{ instance_name }}/secret.conf
      - service: fastd
    - watch:
      - file: /etc/fastd/{{ instance_name }}/fastd.conf
      - file: /etc/fastd/{{ instance_name }}/secret.conf
    {% if network in ['nodes4', 'nodes6'] %}
      - git: peers-git
    {% else %}
      - file: /etc/fastd/{{ instance_name }}/gateways/*
    {% endif %}
  {% endfor %} # // foreach network in $site


#
# Generate Inter-GW peers from pillar
/etc/fastd/{{ site }}_intergw/gateways:
  file.directory:
    - makedirs: true
    - mode: 755
    - require:
      - file: /etc/fastd/{{ site }}_intergw

#
# Set up Inter-Gw-VPN link to all nodes of this site
  {% for node, node_config in salt['pillar.get']('nodes').items ()|sort  %}
/etc/fastd/{{ site }}_intergw/gateways/{{ node }}:
    {% if site in node_config.get ('sites', {}) and 'fastd' in node_config %}
  file.managed:
    - source: salt://fastd/inter-gw.peer.tmpl
    - template: jinja
      site: {{ site }}
      site_no: {{ site_no }}
      node: {{ node }}
      pubkey: {{ salt['pillar.get']('nodes:' ~ node ~ ':fastd:intergw_pubkey') }}
    - require:
      - file: /etc/fastd/{{ site }}_intergw/gateways
    {% else %}
  file.absent
    {% endif %}
  {% endfor %} # // foreach node
{% endfor %} # // foreach site


#
# Cleanup configurations for previosly configured instances.
# Stop fastd instance before purging the configuration.
{% for site in sites_all if site not in sites_node %}
  {% for network in ['intergw', 'nodes4', 'nodes6'] %}
    {% set instance_name = site ~ '_' ~ network %}
Cleanup /etc/fastd/{{ instance_name }}:
  file.absent:
    - name: /etc/fastd/{{ instance_name }}

# Create systemd start link
Stop fastd@{{ instance_name }}:
  service.running:
    - enable: False
    - reload: False
    - prereq:
      - file: Cleanup /etc/fastd/{{ instance_name }}
  {% endfor %}
{% endfor %}


/usr/local/bin/ff_log_vpnpeer:
  file.managed:
    - source: salt://fastd/ff_log_vpnpeer
    - template: jinja
    - mode: 755


ff_fastd_con_pkgs:
  pkg.installed:
    - pkgs:
      - socat
      - jq

/usr/local/bin/ff_fastd_conn:
  file.managed:
    - source: salt://fastd/ff_fastd_con
    - mode: 755
    - user: root
    - group: root

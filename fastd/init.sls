#
# Fastd for gateways
#

{% set sites_all = pillar.get ('sites') %}
{% set node_config = salt['pillar.get']('nodes:' ~ grains.id, {}) %}
{% set sites_node = node_config.get('sites', {}) %}
{% set device_no = node_config.get('id', -1) %}

include:
  - apt
  - network.interfaces
{% if 'fastd_peers' in node_config.get('roles', []) %}
  - fastd.peers
{% endif %}



# Install fastd
fastd:
  pkg.installed:
    - name: fastd
    - require:
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
  {% set site_no = sites_all.get(site, {}).get('site_no') %}

  {% set networks = ['intergw'] %}
  {% if 'fastd_peers' in node_config.get('roles', []) %}
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
      secret: {{ node_config.get('fastd', {}).get(network_type ~ '_privkey') }}
      site: {{ site }}
      site_no: {{ site_no }}
      mac_address: {{ mac_address }}
    {% if 'batman_ext' in node_config.get('roles', []) %}
      bat_iface: bat-{{ site }}-ext
    {% else %}
      bat_iface: bat-{{ site }}
    {% endif %}
      peer_limit: {{ node_config.get('fastd', {}).get('peer_limit', False) }}
    - require:
      - file: /etc/fastd/{{ instance_name }}
    - watch_in:
  
/etc/fastd/{{ instance_name }}/secret.conf:
  file.absent


# Create systemd start link
fastd@{{ instance_name }}:
  service.running:
    - enable: True
    - reload: True
    - require:
      - file: /etc/systemd/system/fastd@.service
      - file: /etc/fastd/{{ instance_name }}/fastd.conf
      - service: fastd
    - watch:
      - file: /etc/fastd/{{ instance_name }}/fastd.conf
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
  {% set has_ipv6 = False %}
  {% if  salt['ffho_net.get_node_iface_ips'](node_config, 'vrf_external')['v6']|length %}
    {% set has_ipv6 = True %}
  {% endif %}
  {% for node, peer_config in salt['pillar.get']('nodes').items ()|sort  %}
/etc/fastd/{{ site }}_intergw/gateways/{{ node }}:
    {% if site in peer_config.get ('sites', {}) and 'fastd' in peer_config %}
  file.managed:
    - source: salt://fastd/inter-gw.peer.tmpl
    - template: jinja
      site: {{ site }}
      site_no: {{ site_no }}
      has_ipv6: {{ has_ipv6 }}
      node: {{ node }}
      pubkey: {{ peer_config.get('fastd', {}).get('intergw_pubkey') }}
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

# stop fastd service
Stop fastd@{{ instance_name }}:
  service.dead:
    - name: fastd@{{ instance_name }}
    - enable: False
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

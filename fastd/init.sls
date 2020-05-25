#
# Fastd for gateways
#

include:
  - network.interfaces

{% set sites_all = pillar.get ('sites') %}
{% set node_config = salt['pillar.get']('nodes:' ~ grains.id, {}) %}
{% set sites_node = node_config.get('sites', {}) %}
{% set device_no = node_config.get('id', -1) %}


# Install fastd
fastd:
  pkg.installed:
    - name: fastd
{% if grains.oscodename in ['jessie'] %}
    - fromrepo: {{ grains.oscodename }}-backports
{% endif %}
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
# Is this instance to be used by external clients?
{% if 'fastd_peers' in node_config.get ('roles', []) %}
# publish blacklist
/etc/fastd/peers-blacklist:
  file.managed:
    - source: salt://fastd/peers-blacklist
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: /etc/fastd

/etc/fastd/verify-peer.sh:
  file.managed:
    - source: salt://fastd/verify-peer.sh
    - user: root
    - group: root
    - mode: 744
    - require:
      - file: /etc/fastd
{% endif %}


#
# Set up fastd configuration for every network (nodes4, nodes6, intergw-vpn)
# for every site associated for the current minion ID.
#
{% for site in sites_all %}
  {% set networks_absent = [] %}
  {% set networks_present = [] %}
  {% set site_no = sites_all.get(site, {}).get('site_no') %}

  {% if site in sites_node %}
    {% do networks_present.extend(['intergw']) %}
    {% if 'fastd_peers' in node_config.get('roles', []) %}
      {% do networks_present.extend(['nodes4', 'nodes6']) %}
    {% else %}
      {% do networks_absent.extend(['nodes4', 'nodes6']) %}
    {% endif %}
  {% else %}
    {% do networks_absent.extend(['intergw', 'nodes4', 'nodes6']) %}
  {% endif %}

  {% for network in networks_present %}
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
  
/etc/fastd/{{ instance_name }}/secret.conf:
  file.absent


# Create systemd start link
fastd@{{ instance_name }}:
  service.running:
    - enable: True
    - require:
      - file: /etc/systemd/system/fastd@.service
      - file: /etc/fastd/{{ instance_name }}/fastd.conf
      - service: fastd
    - watch:
      - file: /etc/fastd/{{ instance_name }}/fastd.conf
  {% endfor %}{# for network in networks #}


#
# Remove old Inter-GW peers folder
/etc/fastd/{{ site }}_intergw/gateways:
  file.absent


#
# Cleanup configurations for previosly configured instances.
# Stop fastd instance before purging the configuration.
  {% for network in networks_absent %}
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
{% endfor %}{# for site in sites_all #}


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

#
# Fastd for gateways
#

{% set sites_all = salt['pillar.get']('netbox:config_context:sites_config') %}
{% set node_config = salt['pillar.get']('nodes:' ~ grains.id, {}) %}
{% set sites_node = salt['pillar.get']('netbox:config_context:sites')
{% set device_no = salt['pillar.get']('netbox:custom_fields:node_id') %}

{% set roles = salt['pillar.get']('netbox:config_context:roles')

{% set sites_all = [] %}
{% for site in sites_node %}
  {% do sites_all.append(sites_node[site]['name'])
{% endfor %}

include:
  - apt
  - network.interfaces
{% if 'fastd_peers' in roles %}
  - fastd.peers
{% endif %}



# Install fastd
fastd:
  pkg.installed:
    - name: fastd
{% if grains.oscodename in ['jessie'] %}
    - fromrepo: {{ grains.oscodename }}-backports
{% endif %}
    - require:
      - sls: network.interfaces
  service.dead:
    - enable: False

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
    {% if network_type == 'nodes' %}
      - git: peers-git
    {% endif %}
  {% endfor %}{# for network in networks #}


#
# Remove old Inter-GW peers folder
/etc/fastd/{{ site }}_intergw/gateways:
  file.absent
{% endfor %}{# for site in sites_node #}


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

#
# Fastd for gateways
#

{% set sites_config = salt['pillar.get']('netbox:config_context:site_config') %}
{% set sites = salt['pillar.get']('netbox:config_context:sites') %}
{% set device_no = salt['pillar.get']('netbox:custom_fields:node_id') %}

{% set fastd_key = salt['pillar.get']('netbox:config_context:fastd:secret_key') %}

include:
  - apt

# Install fastd
fastd:
  pkg.installed:
    - name: fastd
  service.dead:
    - enable: False

/etc/fastd:
  file.directory:
    - user: root
    - group: root
    - mode: 711
  require:
    - pkg: fastd

/etc/systemd/system/fastd@.service:
  file.managed:
    - source: salt://fastd/fastd@.service

#
# Set up fastd configuration for every network (nodes4, nodes6, intergw-vpn)
# for every site associated for the current minion ID.
#
{% for site in sites_config %}

{% set mac_address = "f2:00:" ~ device_no ~ ":" ~ sites_config[site]['site_no'] ~ ":00:00" %}
/etc/fastd/{{ site }}:
  file.directory:
     - makedirs: true
     - mode: 755
     - require:
       - file: /etc/fastd

/etc/fastd/{{ site }}/fastd.conf:
  file.managed:
    - source: salt://fastd/fastd.conf
    - template: jinja
      secret: {{ fastd_key}}
      site: {{ site }}
      site_no: {{ sites_config[site]['site_no'] }}
      fastd_port: {{ sites_config[site]['fastd_port'] }}
      mac_address: {{ mac_address }}
      bat_iface: bat-{{ site }}
    - require:
      - file: /etc/fastd/{{ site }}
  
# Create systemd start link
fastd@{{ site }}:
  service.running:
    - enable: True
    - require:
      - file: /etc/systemd/system/fastd@.service
      - file: /etc/fastd/{{ site }}/fastd.conf
      - service: fastd
    - watch:
      - file: /etc/fastd/{{ site }}/fastd.conf
{% endfor %}


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

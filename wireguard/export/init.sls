
{% set interfaces = salt['pillar.get']('netbox:interfaces') %}
{% for interface in interfaces %}
{% if 'wg-' in interface %}
{% set client_name = interface.split('wg-')[1] %}
{% set wireguard_transfer_net = interfaces[interface]['ipaddresses'][0]['address'] %}
{% set network_id = wireguard_transfer_net.split('.')[3]| regex_replace('/31','') | int %}

/etc/wireguard/export/{{ client_name }}:
    file.directory:
        - makedirs: True

/etc/wireguard/export/{{ client_name }}/wg-{{ grains.id.split('.')[0] }}.conf:
    file.managed:
        - source: salt://wireguard/export/wg.jinja2
        - template: jinja
        - defaults:
          network_id: {{ network_id }}
          client_name: {{ client_name }}
        - require:
           - file: /etc/wireguard/export/{{ client_name }}

{% if grains['id'].split('.')[0] == 'vpn01' %}
# Only generate bird config on vpn01
/etc/wireguard/export/{{ client_name }}/bird.conf:
    file.managed:
        - source: salt://wireguard/export/ebgp4.jinja2
        - template: jinja
        - defaults:
          network_id: {{ network_id }}
        - require:
           - file: /etc/wireguard/export/{{ client_name }}

/etc/wireguard/export/{{ client_name }}/bird6.conf:
    file.managed:
        - source: salt://wireguard/export/ebgp6.jinja2
        - template: jinja
        - defaults:
          network_id: {{ network_id }}
        - require:
           - file: /etc/wireguard/export/{{ client_name }}
{% endif %}{# grains.id == vpn01 #}

{% endif %}{# 'wg-' in interface #}
{% endfor %}
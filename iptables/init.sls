iptables_pkgs:
  pkg.installed:
    - names:
      - iptables-persistent
      - netfilter-persistent

{% if "guardian" in grains.id %}

{% set own_location = salt['pillar.get']('netbox:site:name') %}

{% if salt['grains.get']('ip4_interfaces:vlan3:0') %}
  {% set nat_ip = salt['grains.get']('ip4_interfaces:vlan3:0') %}
{% else %}
  {% set nat_ip = salt['grains.get']('ip4_interfaces:dummy0:0') %}
{% endif %}

{% set nodes = salt['mine.get']('netbox:platform:slug:linux', 'minion_id', tgt_type='pillar') %}
{% for node in nodes %}
{%- set node_location = salt['mine.get'](node, 'minion_location', tgt_type='glob') %}
# Are we in the same location as our minion?
{% if own_location == node_location[node] %}

{%- set overlay_address = salt['mine.get'](node,'minion_overlay_address', tgt_type='glob') %}
{%- set minion_address = salt['mine.get'](node,'minion_address', tgt_type='glob')[node] %}

{%- if overlay_address and overlay_address[node] | length > 0 and not '__data__' in overlay_address[node] %}

{% set nebula_internal_ip_split = overlay_address[node].split('/')[0].split('.') %}
{% set n1 = nebula_internal_ip_split[2] | int %}
{% set n2 = nebula_internal_ip_split[3] | int %}

{{ node }}_{{ own_location }}_nebula_dnat:
  iptables.insert:
    - table: nat
    - position: 1
    - family: ipv4
    - chain: PREROUTING
    - protocol: udp
    - destination: {{ nat_ip }}
    - jump: DNAT
    - dport: {{ 20000 + n1 * 256 + n2  }}
    - to-destination: {{ minion_address.split('/')[0] }}
    - save: True

{{ node }}_{{ own_location }}_nebula_snat:
  iptables.insert:
    - table: nat
    - position: 1
    - family: ipv4
    - chain: POSTROUTING
    - protocol: udp
    - source: {{ minion_address.split('/')[0] }}
    - jump: SNAT
    - sport: {{ 20000 + n1 * 256 + n2  }}
    - to: {{ nat_ip }}:{{ 20000 + n1 * 256 + n2  }}
    - save: True
{% endif %}
{% endif %}{# if own_location == node_location[node] #}
{% endfor %}{# for node in nodes #}
{% endif %}{# if guardian #}

#
# Authoritive FFMuc DNS Server configuration
#


# Get all nodes for DNS records
{% set nodes = salt['mine.get']('netbox:platform:slug:linux', 'minion_id', tgt_type='pillar') %}
{% set cnames = salt['pillar.get']('netbox:config_context:dns_zones:cnames') %}
{% set custom_records = salt['pillar.get']('netbox:config_context:dns_zones:custom_records', []) %}

ffmuc.net:
  cloudflare.manage_zone_records:
    - zone:
        api_token: {{ salt['pillar.get']('netbox:config_context:cloudflare:api_token') }}
        zone_id: d8d8e7a6ab00df3cc05f66fb0aa232e2
        exclude:
               - ^(?!.*(\.ext)).*
        records:
{# Create DNS records for each node #}
{%- for node_id in nodes %}
{%- set external_address = salt['mine.get'](node_id,'minion_external_ip', tgt_type='glob') %}
{%- set external_address6 = salt['mine.get'](node_id,'minion_external_ip6', tgt_type='glob') %}
{%- if external_address and not '__data__' in external_address[node_id] and external_address[node_id][0] is defined and external_address[node_id] | length > 0 %}
{%- set node = node_id | regex_search('(^\w+(-)?(\w+)?(\d+)?)') %}
                - name: {{ node[0] }}.ext.ffmuc.net
                  content: "{{ external_address[node_id] | first }}"
                  salt_managed: True
                  type: A
{% endif %}{# external_address #}
{% if external_address6 and not '__data__' in external_address6[node_id] and external_address6[node_id][0] is defined and external_address6[node_id] | length > 0 %}
{% set node = node_id | regex_search('(^\w+(-)?(\w+)?(\d+)?)') %}
                - name: {{ node[0] }}.ext.ffmuc.net
                  content: "{{ external_address6[node_id] | first }}"
                  salt_managed: True
                  type: AAAA
{%- endif %}
{%- endfor %} {# for node_id in nodes #}
# Create CNAMES as defined in netbox:config_context:dns_zones:cnames or netbox:services (cnames field needs to be set to True)
{%- set services = salt['pillar.get']('netbox:services') %}
{%- for service in services %}
{%- if services[service]['custom_fields']['cname'] %}
{%- if services[service]['virtual_machine'] %}
{%- if services[service]['custom_fields']['public'] %}
{%- set target = services[service]['virtual_machine']['name'] | regex_search('(^\w+(-)?(\w+)?(\d+)?)') %}
{%- do cnames.update({service: target[0] ~ '.ext.ffmuc.net' }) %}
{%- else %}
{%- do cnames.update({service: services[service]['virtual_machine']['name'] }) %}
{%- endif %}
{%- else %}
{%- if services[service]['custom_fields']['public'] %}
{%- set target = services[service]['device']['name'] | regex_search('(^\w+(-)?(\w+)?(\d+)?)') %}
{%- do cnames.update({service: target[0] ~ '.ext.ffmuc.net' }) %}
{%- else %}
{%- do cnames.update({service: services[service]['device']['name'] }) %}
{%- endif %}
{%- endif %}
{%- endif %}
{%- endfor %}
{%- for cname in cnames %}
{%- if 'in.ffmuc.net' not in cname %}
                - name: {{ cname  }}
                  content: {{ cnames[cname] }} 
                  salt_managed: True
                  type: CNAME
{%- endif %}
{%- endfor %}{# cname in cnames #}


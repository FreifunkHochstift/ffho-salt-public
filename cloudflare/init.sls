#
# Authoritive FFMuc DNS Server configuration
#

# Get all nodes for DNS records
{%- set nodes = salt['mine.get']('netbox:platform:slug:linux', 'minion_id', tgt_type='pillar') %}
{%- set cnames = salt['pillar.get']('netbox:config_context:dns_zones:cnames') %}
{%- set custom_records = salt['pillar.get']('netbox:config_context:dns_zones:custom_records', []) %}
{%- set node_has_overlay = [] %}{# List of node[0] #}

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
  {%- set overlay_address = salt['mine.get'](node_id,'minion_nebula_address', tgt_type='glob') %}
  {%- if external_address and not '__data__' in external_address[node_id] and external_address[node_id] | length > 0 %}
    {%- set node = node_id | regex_search('(^\w+(\d+)?)') %}
                - name: {{ node[0] }}.ext.ffmuc.net
                  content: {{ external_address[node_id] | first }} 
                  salt_managed: True
                  type: A
  {%- endif %}{# external_address #}
  {%- if external_address6 and not '__data__' in external_address6[node_id] and external_address6[node_id] | length > 0 %}
    {%- set node = node_id | regex_search('(^\w+(\d+)?)') %}
                - name: {{ node[0] }}.ext.ffmuc.net
                  content: {{ external_address6[node_id] | first }} 
                  salt_managed: True
                  type: AAAA
  {%- endif %}{# external_address6 #}
  {%- if overlay_address and not '__data__' in overlay_address[node_id] and overlay_address[node_id] | length > 0 %}
    {%- set node = node_id | regex_search('(^\w+(\d+)?)') -%}
    {%- do node_has_overlay.append(node[0]) %}
                - name: {{ node[0] }}.ov.ffmuc.net
                  content: {{ overlay_address[node_id] | regex_replace('/\d+$','') }}
                  salt_managed: True
                  type: A
  {%- endif %}{# overlay_address #}
{%- endfor %} {# for node_id in nodes #}

{# Create CNAMES as defined in netbox:config_context:dns_zones:cnames or netbox:services (cnames field needs to be set to True) #}
{%- set services = salt['pillar.get']('netbox:services') %}
{%- for service in services %}
  {%- if services[service]['custom_fields']['cname'] %}
    {%- if services[service]['virtual_machine'] %}
      {%- set target = services[service]['virtual_machine']['name'] | regex_search('(^\w+(\d+)?)') %}
      {%- if services[service]['custom_fields']['public'] %}
        {%- do cnames.update({service: target[0] ~ '.ext.ffmuc.net' }) %}
      {%- else %}{# if services[service]['custom_fields']['public'] #}
        {%- if target[0] in node_has_overlay %}
          {%- do cnames.update({service: target[0] ~ '.ov.ffmuc.net' }) %}
        {%- else %}{# target[0] in node_has_overlay #}
          {%- do cnames.update({service: services[service]['virtual_machine']['name'] }) %}
        {%- endif %}{# target[0] in node_has_overlay #}
      {%- endif %}{# if services[service]['custom_fields']['public'] #}
    {%- else %}{# if services[service]['virtual_machine'] #}
      {%- set target = services[service]['device']['name'] | regex_search('(^\w+(\d+)?)') %}
      {%- if services[service]['custom_fields']['public'] %}
        {%- do cnames.update({service: target[0] ~ '.ext.ffmuc.net' }) %}
      {%- else %}{# if services[service]['custom_fields']['public'] #}
      # {{ target[0] }} - {{ node_has_overlay }}
        {%- if target[0] in node_has_overlay %}
          {%- do cnames.update({service: target[0] ~ '.ov.ffmuc.net' }) %}
        {%- else %}{# target[0] in node_has_overlay #}
          {%- do cnames.update({service: services[service]['device']['name'] }) %}
        {%- endif %}{# target[0] in node_has_overlay #}
      {%- endif %}{# if services[service]['custom_fields']['public'] #}
    {%- endif %}{# if services[service]['virtual_machine'] #}
  {%- endif %}{# services[service]['custom_fields']['cname'] #}
{%- endfor %}{# for service in services #}

{%- for cname in cnames %}
  {%- if 'in.ffmuc.net' not in cname %}
                - name: {{ cname  }}
                  content: {{ cnames[cname] }} 
                  salt_managed: True
                  type: CNAME
  {%- else %}
    {%- set target = cname | regex_search('(^\w+(-)?(\w+)?(\d+)?)') %}
                - name: {{ target[0] ~ '.ov.ffmuc.net' }}
                  content: {{ cnames[cname] }} 
                  salt_managed: True
                  type: CNAME
  {%- endif %}
{%- endfor %}{# cname in cnames #}


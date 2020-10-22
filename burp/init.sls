#
# Burp backup
#
{%- set role = salt['pillar.get']('netbox:role:name', salt['pillar.get']('netbox:device_role:name')) %}

include:
 - certs
 {%- if 'backupserver' in role %}
 - burp.repo
 - burp.server
 {%- elif 'backup_client' in salt['pillar.get']('netbox:config_context:roles')  %}
 - burp.repo
 - burp.client
 {%- endif %}
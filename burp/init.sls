#
# Burp backup
#
{% if salt['pillar.get']('netbox:role:name') %}
{%- set role = salt['pillar.get']('netbox:role:name') %}
{% else %}
{%- set role = salt['pillar.get']('netbox:device_role:name') %}
{% endif %}
include:
 - certs
 {%- if 'backupserver' in role %}
 - burp.server
 {%- elif 'backup_client' in salt['pillar.get']('netbox:config_context:roles')  %}
 - burp.client
 {%- endif %}

{% if 'Ubuntu' not in  grains.lsb_distrib_id%}
burp-repo:
  pkgrepo.managed:
    - name: deb http://ziirish.info/repos/debian/{{ grains.oscodename }}/ zi-latest main
    - clean_file: True
    - file: /etc/apt/sources.list.d/burp.list
    - keyserver: keys.gnupg.net
    - keyid: A1718780C58CD6E3
{% endif %}
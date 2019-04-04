#
# Burp backup - Client
#

include:
 - burp

{% if grains.osfullname in 'Raspbian' %}
burp:
  pkg.installed
{% else %}
burp-client:
  pkg.installed
{% endif %}

/etc/default/burp-client:
  file.managed:
    - source: salt://burp/default_burp-client

/etc/cron.d/burp:
  file.managed:
    - source: salt://burp/burp-cron

/etc/burp/burp.conf:
  file.managed:
    - source: salt://burp/burp.conf.tmpl
    - template: jinja
      burp_server_name: "backup01.in.ffmuc.net"
      burp_password: {{ salt['pillar.get']('netbox:services:backup.in.ffmuc.net:custom_fields:api_token') }}

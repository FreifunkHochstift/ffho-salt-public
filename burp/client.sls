#
# Burp backup - Client
#

include:
 - burp


burp-client:
  pkg.installed

/etc/default/burp-client:
  file.managed:
    - source: salt://burp/client/default_burp

/etc/burp/burp.conf:
  file.managed:
    - source: salt://burp/client/burp.conf.tmpl
    - template: jinja
      burp_server_name: {{ salt['pillar.get']('burp:server:fqdn') }}
      burp_password: {{ salt['pillar.get']('nodes:' ~ grains.id ~ ':burp:password') }}

#
# Burp backup - Client
#

include:
 - burp


burp-client:
  pkg.installed

/etc/default/burp-client:
  file.managed:
    - source: salt://burp/default_burp-client

/etc/burp/burp.conf:
  file.managed:
    - source: salt://burp/burp.conf.tmpl
    - template: jinja
      burp_server_name: "hamster.in.ffho.net"
      burp_password: {{ salt['pillar.get']('nodes:' ~ grains.id ~ ':burp:password') }}

#
# burp backup server
#

include:
 - burp


burp-server:
  pkg.installed

/etc/default/burp:
  file.managed:
    - source: salt://burp/default_burp

/etc/burp/burp.conf:
  file.managed:
    - source: salt://burp/burp-server.conf.tmpl
    - template: jinja

/etc/burp/clientconfdir:
  file.directory:
    - mode: 700

{% set nodes = salt['pillar.get']('nodes') %}
{% for node, node_config in nodes.items()|sort if 'burp' in node_config %}
/etc/burp/clientconfdir/{{ node }}:
   file.managed:
     - source: salt://burp/client.tmpl
     - template: jinja
     - context:
       node: {{ node }}
       burp_config: {{ node_config.get ('burp') }}
{% endfor %}

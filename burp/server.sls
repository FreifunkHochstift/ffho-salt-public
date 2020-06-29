#
# burp backup server
#

include:
 - burp


burp-server:
  pkg.installed:
    - name: burp-server
  service.running:
    - enable: True
    - restart: True

/etc/default/burp:
  file.managed:
    - source: salt://burp/server/default_burp
    - watch_in:
      - service: burp-server

/etc/burp/burp-server.conf:
  file.managed:
    - source: salt://burp/server/burp-server.conf.tmpl
    - template: jinja
    - watch_in:
      - service: burp-server

/etc/burp/clientconfdir:
  file.directory:
    - mode: 700

/etc/burp/clientconfdir/incexc:
  file.directory:
    - require:
      - file: /etc/burp/clientconfdir

/etc/burp/clientconfdir/incexc/common:
  file.managed:
    - source: salt://burp/server/common_incexc
    - require:
      - file: /etc/burp/clientconfdir/incexc
    - watch_in:
      - service: burp-server

{% set nodes = salt['pillar.get']('nodes') %}
{% for node, node_config in nodes.items()|sort if 'burp' in node_config %}
/etc/burp/clientconfdir/{{ node }}:
  file.managed:
    - source: salt://burp/server/client.tmpl
    - template: jinja
    - context:
      node: {{ node }}
      burp_config: {{ node_config.get ('burp') }}
    - watch_in:
      - service: burp-server
{% endfor %}

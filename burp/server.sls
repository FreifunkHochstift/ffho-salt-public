#
# burp backup server
#

include:
 - burp


burp-server:
  pkg.installed:
    - refresh: True
    - require:
      - pkgrepo: burp-repo
  service.running:
    - enable: true
    - restart: true

/usr/share/burp/scripts/burp_notify_mattermost.sh:
  file.managed:
    - source: salt://burp/burp_notify_mattermost.sh.tmpl
    - mode: 755
    - template: jinja

/etc/default/burp:
  file.managed:
    - source: salt://burp/default_burp

/etc/burp/burp-server.conf:
  file.managed:
    - source: salt://burp/burp-server.conf.tmpl
    - template: jinja

/etc/burp/clientconfdir:
  file.directory:
    - mode: 700

{% for node,data in salt['mine.get']('netbox:config_context:roles:backup_client', 'minion_id', tgt_type='pillar').items() %}
/etc/burp/clientconfdir/{{ node }}:
   file.managed:
     - source: salt://burp/client.tmpl
     - template: jinja
     - context:
         node: {{ node }}
         burp_config: {{ node }}
{% endfor %}

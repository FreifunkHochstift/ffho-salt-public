##
# Prosody for jitsi
##
{%- from "jitsi/map.jinja" import jitsi with context %}

prosody-repo:
  pkgrepo.managed:
    - humanname: Prosody
    - name: deb http://packages.prosody.im/debian {{ grains.oscodename }} main
    - file: /etc/apt/sources.list.d/prosody.list
    - key_url: https://prosody.im/files/prosody-debian-packages.key
    - clean_file: True

prosody:
  pkg.installed:
    - name: prosody
    - require:
      - pkgrepo: prosody-repo
  service.running:
    - enable: True
    - reload: True
    - watch:
       - file: /etc/prosody/prosody.cfg.lua
       - file: /etc/prosody/conf.d/{{ jitsi.public_domain }}.cfg.lua

/etc/prosody/prosody.cfg.lua:
  file.managed:
    - source: salt://jitsi/prosody/prosody.cfg.lua.jinja
    - template: jinja

/etc/prosody/conf.d/{{ jitsi.public_domain }}.cfg.lua:
  file.managed:
    - source: salt://jitsi/prosody/domain.cfg.lua.jinja
    - template: jinja

jicofo-auth:
  cmd.run:
    - name: "prosodyctl register {{ jitsi.jicofo.username }} {{ jitsi.xmpp.auth_domain }} {{ jitsi.jicofo.password }}"
    - creates: /var/lib/prosody/{{ jitsi.xmpp.auth_domain.replace('.', '%2e').replace('-', '%2d') }}/accounts/{{ jitsi.jicofo.username }}.dat

jvb-auth:
  cmd.run:
    - name: "prosodyctl register {{ jitsi.videobridge.username }} {{ jitsi.xmpp.auth_domain }} {{ jitsi.videobridge.password }}"
    - creates: /var/lib/prosody/{{ jitsi.xmpp.auth_domain.replace('.', '%2e').replace('-', '%2d') }}/accounts/{{ jitsi.videobridge.username }}.dat

{% for domain in [ jitsi.public_domain , jitsi.xmpp.auth_domain ] %}
prosody-{{domain}}-cert:
  cmd.run:
    - name: "yes '' | /usr/bin/prosodyctl cert generate {{domain}}"
    - creates: /var/lib/prosody/{{domain}}.crt

{% for ext in ["crt", "key"] %}
/etc/prosody/certs/{{domain}}.{{ ext }}:
  file.symlink:
    - target: /var/lib/prosody/{{domain}}.{{ ext }}

{% endfor %}{# ext #}
{% endfor %}{# domain #}

{% for component in ["mod_reload_components", "mod_reload_modules"] %}
/usr/lib/prosody/modules/{{ component }}.lua:
  file.managed:
    - source: https://hg.prosody.im/prosody-modules/raw-file/tip/{{ component }}/{{ component }}.lua
    - skip_verify: True
    - watch_in:
      - service: prosody

{% endfor %}
{% for component in [
  "ext_events.lib",
  "mod_conference_duration",
  "mod_conference_duration_component",
  "mod_muc_lobby_rooms",
  "mod_muc_meeting_id",
  "mod_smacks",
  "mod_speakerstats",
  "mod_speakerstats_component",
  "mod_turncredentials",
  "util.lib"] %}
/usr/lib/prosody/modules/{{ component }}.lua:
  file.managed:
    - source: https://raw.githubusercontent.com/jitsi/jitsi-meet/master/resources/prosody-plugins/{{ component }}.lua
    - skip_verify: True
    - watch_in:
      - service: prosody

{% endfor %}
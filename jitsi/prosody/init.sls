##
# Prosody for jitsi (WIP)
##
{%- from "jitsi/map.jinja" import jitsi with context %}

{% if jitsi.prosody.enabled %}

prosody-repo:
  pkgrepo.managed:
    - humanname: Prosody
    - name: deb http://packages.prosody.im/debian {{ grains.oscodename }} main
    - file: /etc/apt/sources.list.d/prosody.list
    - key_url: https://prosody.im/files/prosody-debian-packages.key
    - clean_file: True

# Hacks for enabling token auth in jitsi
# https://community.jitsi.org/t/jitsi-meet-tokens-chronicles-on-debian-buster/76756
# orig file path: https://emrah.com/files/lua-cjson-2.1devel-1.linux-x86_64.rock
/tmp/lua-cjson-2.1devel-1.linux-x86_64.rock:
  file.managed:
    - source: salt://jitsi/prosody/lua-cjson-2.1devel-1.linux-x86_64.rock
    - require_in:
      - cmd: luarocks-/tmp/lua-cjson-2.1devel-1.linux-x86_64.rock

{% for luapkg in [
  "cyrussasl 1.1.0-1",
  "net-url 0.9-1",
  "luajwtjitsi 2.0-0"
  "/tmp/lua-cjson-2.1devel-1.linux-x86_64.rock"] %}
luarocks-{{ luapkg }}:
  cmd.run:
    - name: "luarocks install {{ luapkg }}"
    - require:
      - pkg: prosody-dependencies

{% endfor %}{# luapkg #}

prosody:
  pkg.installed:
    - name: prosody-0.11 # This is the nightly build. use "prosody" for stable
    - require:
      - pkgrepo: prosody-repo
  service.running:
    - enable: True
    - reload: True
    - watch:
      - file: /etc/prosody/prosody.cfg.lua
      - file: /etc/prosody/conf.d/{{ jitsi.public_domain }}.cfg.lua

{# download and extract prosody plugins of jitsi #}
download-jitsi-meet-prosody:
  pkg.downloaded:
    - name: jitsi-meet-prosody
    - required_in:
      - cmd: extract_prosody_modules

extract_prosody_modules:
  cmd.run:
    - name: dpkg -x /var/cache/apt/archives/jitsi-meet-prosody*.deb /tmp/jitsi-prosody-modules
    - onchanges:
      - pkg: download-jitsi-meet-prosody
    - require:
      - pkg: download-jitsi-meet-prosody

copy-prosody-plugins:
  file.recurse:
    - name: /usr/share/jitsi-meet/prosody-plugins/
    - source: /tmp/jitsi-prosody-modules/usr/share/jitsi-meet/prosody-plugins/
    - onchanges:
      - cmd: extract_prosody_modules
    - require:
      - pkg: extract_prosody_modules

remove-temporary-files:
  file.absent:
    - names:
      - /var/cache/apt/archives/jitsi-meet-prosody*.deb
      - /tmp/jitsi-prosody-modules
    - require:
      - file: copy-prosody-plugins

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

{%- if jitsi.jibri_enabled %}
jibri-control-auth:
  cmd.run:
    - name: "prosodyctl register {{ jitsi.jibri.xmpp.control_login.username }} {{ jitsi.jibri.xmpp.control_login.domain }} {{ jitsi.jibri.xmpp.control_login.password }}"
    - creates: /var/lib/prosody/{{ jitsi.jibri.xmpp.control_login.domain.replace('.', '%2e').replace('-', '%2d') }}/accounts/{{ jitsi.jibri.xmpp.control_login.username }}.dat

jibri-recorder-auth:
  cmd.run:
    - name: "prosodyctl register {{ jitsi.jibri.xmpp.call_login.username }} {{ jitsi.jibri.xmpp.call_login.domain }} {{ jitsi.jibri.xmpp.call_login.password }}"
    - creates: /var/lib/prosody/{{ jitsi.jibri.xmpp.call_login.domain.replace('.', '%2e').replace('-', '%2d') }}/accounts/{{ jitsi.jibri.xmpp.call_login.username }}.dat
{% endif %}

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

/usr/local/share/ca-certificates/{{ jitsi.xmpp.auth_domain }}.crt:
  file.symlink:
    - target: /var/lib/prosody/{{ jitsi.xmpp.auth_domain }}.crt

update-certificates:
  cmd.run:
    - name: "/usr/sbin/update-ca-certificates --fresh"

{% for component in [
  "mod_auth_token",
  "mod_reload_components",
  "mod_reload_modules" ] %}
/usr/lib/prosody/modules/{{ component }}.lua:
  file.managed:
    - source: https://hg.prosody.im/prosody-modules/raw-file/tip/{{ component }}/{{ component }}.lua
    - skip_verify: True
    - watch_in:
      - service: prosody

{% endfor %}{# for component #}

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

{% endfor %}{# for component #}
{% endif %}{# if jitsi.prosody.enabled #}

###
# install jibri
###
{%- from "jitsi/map.jinja" import jitsi with context %}

{% if jitsi.videobridge.enabled %}

jitsi-videobridge2:
  pkg.installed:
    - require:
      - pkgrepo: jitsi-repo
  service.running:
    - enable: True
    - reload: True

### set static hostname and the like
stats.in.ffmuc.net:
  host.present:
    - ip: 10.111.0.254
jicofo-and-xmpp-ip:
  host.present:
    - names:
       - {{ jitsi.videobridge.jicofo.hostname }}
    - ip: 10.111.0.1

videobridge-system-config:
  network.system:
    - enabled: True
    - hostname: "{{jitsi.videobridge.subdomain}}.{{jitsi.videobridge.jicofo.hostname}}"
    - nisdomain: "{{jitsi.videobridge.jicofo.hostname}}"
    - apply_hostname: True

/etc/jitsi/videobridge/config.json:
  file.managed:
    - source: jitsi/videobridge/config.json.jinja
    - template: jinja

/etc/jitsi/videobridge/sip-communicator.properties:
  file.managed:
    - source: jitsi/videobridge/sip-communicator.properties.jinja
    - template: jinja

/usr/share/jitsi-videobridge/lib/videobridge.rc:
  file.managed:
    - source: jitsi/videobridge/videobridge.rc
    - template: jinja

/etc/systemd/system/jitsi-videobridge2.service.d/override.conf:
  file.managed:
    - source: jitsi/videobridge/systemd-override.conf

{% endif %}
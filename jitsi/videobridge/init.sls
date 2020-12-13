###
# install jibri
###
{%- from "jitsi/map.jinja" import jitsi with context %}

{% if jitsi.videobridge.enabled %}

include:
  - jitsi.base

jitsi-videobridge2:
  pkg.installed:
    - require:
      - pkgrepo: jitsi-repo
  service.running:
    - enable: True

systemd-reload-jvb:
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:  
      - file: /etc/systemd/system/jitsi-videobridge2.service.d/override.conf
    - watch_in:
      - service: jitsi-videobridge2

### set static hostname and the like
stats.in.ffmuc.net:
  host.present:
    - ip: 10.111.0.254
#jicofo-and-xmpp-ip:
#  host.present:
#    - names:
#       - {{ jitsi.videobridge.jicofo.hostname }}
#    - ip: 10.111.0.1
#
#videobridge-system-config:
#  network.system:
#    - enabled: True
#    - hostname: "{{ grains.id.split('.')[0] }}.{{jitsi.videobridge.jicofo.hostname}}"
#    - nisdomain: "{{jitsi.videobridge.jicofo.hostname}}"
#    - apply_hostname: True

/etc/jitsi/videobridge/config:
  file.managed:
    - source: salt://jitsi/videobridge/config.jinja
    - template: jinja
    - watch_in:
        - service: jitsi-videobridge2

/etc/jitsi/videobridge/jvb.conf:
  file.managed:
    - source: salt://jitsi/videobridge/jvb.conf.jinja
    - template: jinja
    - watch_in:
        - service: jitsi-videobridge2

/etc/jitsi/videobridge/sip-communicator.properties:
  file.managed:
    - source: salt://jitsi/videobridge/sip-communicator.properties.jinja
    - template: jinja
    - watch_in:
        - service: jitsi-videobridge2

/usr/share/jitsi-videobridge/lib/videobridge.rc:
  file.managed:
    - source: salt://jitsi/videobridge/videobridge.rc
    - template: jinja
    - watch_in:
        - service: jitsi-videobridge2

/etc/systemd/system/jitsi-videobridge2.service.d/override.conf:
  file.managed:
    - source: salt://jitsi/videobridge/systemd-override.conf
    - makedirs: True

{% else %}
# stop and disable videobridge
jitsi-videobridge2:
  service.dead:
    - enable: False

{% endif %}
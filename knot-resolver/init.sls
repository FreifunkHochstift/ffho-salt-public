#
# knot-recursor
#

knot-resolver-repo:
  pkgrepo.managed:
{% if grains.oscodename in ["stretch"] %}
    - name: "deb http://download.opensuse.org/repositories/home:/CZ-NIC:/knot-resolver-latest/Debian_9.0/ /"
    - key_url: https://download.opensuse.org/repositories/home:CZ-NIC:knot-resolver-latest/Debian_9.0/Release.key
{% elif grains.oscodename in ["buster"] %}
    - name: "deb http://download.opensuse.org/repositories/home:/CZ-NIC:/knot-resolver-latest/Debian_10/ /"
    - key_url: https://download.opensuse.org/repositories/home:CZ-NIC:knot-resolver-latest/Debian_10/Release.key
{% else %}
    - name: "deb http://download.opensuse.org/repositories/home:/CZ-NIC:/knot-resolver-latest/Debian_Next/ /"
    - key_url: https://download.opensuse.org/repositories/home:CZ-NIC:knot-resolver-latest/Debian_Next/Release.key
{% endif %}
    - clean_file: True
    - file: /etc/apt/sources.list.d/knot-resolver.list

knot-resolver:
  pkg.installed:
    - refresh: True
    - require:
      - pkgrepo: knot-resolver-repo
  service.running:
    - name: kresd@1
    - enable: True
    - restart: True
    - require:
      - file: knot-socket-override
      - file: knot-service-override
      - file: /etc/knot-resolver/kresd.conf
    - watch:
      - file: /etc/knot-resolver/kresd.conf
      - cmd: systemd-reload

systemd-reload-knot-res:
  cmd.run:
   - name: systemctl --system daemon-reload
   - onchanges:
     - file: knot-socket-override
     - file: knot-service-override

knot-service-override:
  file.managed:
    - name: /etc/systemd/system/kresd@.service.d/override.conf
    - source: salt://knot-resolver/kresd@.override.service
    - makedirs: True

knot-socket-override:
  file.managed:
    - name: /etc/systemd/system/kresd.socket.d/override.conf
    - source: salt://knot-resolver/kresd.override.socket
    - template: jinja
    - makedirs: True
  service.running:
    - name: kresd.socket
    - enable: True
    - restart: True
    - require:
      - file: /etc/systemd/system/kresd.socket.d/override.conf
    - watch:
      - file: /etc/systemd/system/kresd.socket.d/override.conf

/etc/knot-resolver/kresd.conf:
  file.managed:
    - source: salt://knot-resolver/kresd.conf
    - template: jinja

# workaround for module prefill which downloads root zone
internic-host:
  host.present:
    - ip:
      - 192.0.32.9
      - 2620:0:2d0:200::9
    - name: www.internic.net
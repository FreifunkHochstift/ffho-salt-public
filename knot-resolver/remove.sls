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
    - enabled: False

knot-resolver:
  pkg.removed


/etc/systemd/system/kresd@1.service.d:
  file.absent

/etc/systemd/system/kresd.socket.d:
  file.absent

/etc/knot-resolver:
  file.absent

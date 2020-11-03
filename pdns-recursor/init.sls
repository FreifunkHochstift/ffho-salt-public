#
# pdns-recursor
#

pdns-repo:
  pkgrepo.managed:
    - name: deb [arch=amd64] http://repo.powerdns.com/{{ grains.lsb_distrib_id | lower }} {{ grains.oscodename }}-rec-44 main
    - clean_file: True
    - key_url: https://repo.powerdns.com/FD380FBB-pub.asc
    - file: /etc/apt/sources.list.d/pdns.list

pdns-recursor:
  pkg.installed:
    - refresh: True
    - require:
      - pkgrepo: pdns-repo
  service.running:
    - enable: True
    - restart: True
    - require:
      - file: /etc/systemd/system/pdns-recursor.service
      - file: /etc/powerdns/recursor.conf
    - watch:
      - file: /etc/powerdns/recursor.conf

systemd-resolved:
  service.dead:
    - enable: False

systemd-reload-pdns-rec:
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: /etc/systemd/system/pdns-recursor.service.d/override.conf
      - file: /etc/systemd/system/pdns-recursor.service
    - watch_in:
      - service: pdns-recursor

/etc/systemd/system/pdns-recursor.service.d/override.conf:
{#{% if 'vrf_external' in salt['grains.get']('ip_interfaces') %}
#  file.managed:
#    - name: /etc/systemd/system/pdns-recursor.service.d/override.conf
#    - source: salt://pdns-recursor/pdns-recursor.override.service
#    - template: jinja
#    - makedirs: True
#{% else %}#}
  file.absent
{#% endif %#}

/etc/systemd/system/pdns-recursor.service:
{% if 'vrf_external' in salt['grains.get']('ip_interfaces') %}
  file.managed:
    - source: salt://pdns-recursor/pdns-recursor.service
    - template: jinja
{% else %}
  file.absent
{% endif %}

/etc/powerdns/recursor.conf:
  file.managed:
    - source: salt://pdns-recursor/recursor.conf
    - template: jinja

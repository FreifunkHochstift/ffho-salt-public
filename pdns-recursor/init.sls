#
# pdns-recursor
#

pdns-repo:
  pkgrepo.managed:
    - name: deb [arch=amd64] http://repo.powerdns.com/debian {{ grains.oscodename }}-rec-44 main
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
      - file: pdns-recursor-service-override
      - file: /etc/powerdns/recursor.conf
    - watch:
      - file: /etc/powerdns/recursor.conf

systemd-reload-pdns-rec:
  cmd.run:
   - name: systemctl --system daemon-reload
   - onchanges:
     - file: pdns-recursor-service-override
     - file: /etc/systemd/system/pdns-recursor.service

pdns-recursor-service-override:
  file.absent:
    - name: /etc/systemd/system/pdns-recursor.d/override.conf
#    - source: salt://pdns-recursor/pdns-recursor.override.service
#    - makedirs: True

/etc/systemd/system/pdns-recursor.service:
  file.managed:
    - source: salt://pdns-recursor/pdns-recursor.service
    - template: jinja

/etc/powerdns/recursor.conf:
  file.managed:
    - source: salt://pdns-recursor/recursor.conf
    - template: jinja

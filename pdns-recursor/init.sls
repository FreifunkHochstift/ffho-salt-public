#
# pdns-recursor
#

pdns-repo:
  pkgrepo.managed:
    - name: deb [arch=amd64] http://repo.powerdns.com/debian stretch-rec-42 main
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

/etc/systemd/system/pdns-recursor.service:
  file.managed:
    - source: salt://pdns-recursor/pdns-recursor.service

/etc/powerdns/recursor.conf:
  file.managed:
    - source: salt://pdns-recursor/recursor.conf

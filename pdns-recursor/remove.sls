#
# pdns-recursor
#

pdns-repo:
  pkgrepo.managed:
    - name: deb [arch=amd64] http://repo.powerdns.com/debian {{ grains.oscodename }}-rec-42 main
    - clean_file: True
    - key_url: https://repo.powerdns.com/FD380FBB-pub.asc
    - file: /etc/apt/sources.list.d/pdns.list
    - enabled: False

pdns-recursor:
  pkg.removed

/etc/systemd/system/pdns-recursor.service:
  file.absent

/etc/systemd/system/pdns-recursor.d:
  file.absent

/etc/powerdns/recursor.conf:
  file.absent

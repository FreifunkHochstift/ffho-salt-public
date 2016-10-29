#
# Postfix
#

# Force installation of bsd-mailx as it's not installed anymore in Debian Jessie..
bsd-mailx:
  pkg.installed:
    - name: bsd-mailx


postfix:
  pkg.installed:
    - name: postfix
    - requires:
      - file: /etc/mailname
  service.running:
    - enable: true
    - reload: true

#
# Don't listen on port 25, by default, a unix socket is enough.
/etc/postfix/master.cf:
  file.managed:
    - source:
      - salt://postfix/master.cf.{{ grains['id'] }}
      - salt://postfix/master.cf.{{ grains['nodename'] }}
      - salt://postfix/master.cf.{{ grains.oscodename }}
      - salt://postfix/master.cf
    - watch_in:
      - service: postfix

#
# Send root mail to ops@ffho.net
/etc/aliases:
  file.managed:
    - source: salt://postfix/aliases

newaliases:
  cmd.wait:
    - name: /usr/bin/newaliases
    - watch:
      - file: /etc/aliases


# Set mailname for xxx.paderborn.freifunk.net (FIXME)
/etc/mailname:
  file.managed:
    - contents: "{{ grains.nodename }}.paderborn.freifunk.net"

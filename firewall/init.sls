#
# Netfiler stuff
#

/etc/modules-load.d/netfilter:
  file.managed:
    - source: salt://firewall/modules


iptables-persistent:
  pkg.installed

iptables-restore:
  cmd.wait:
    - name: /sbin/iptables-restore < /etc/iptables/rules.v4
    - watch:
      - file: /etc/iptables/rules.v4

ip6tables-restore:
  cmd.wait:
    - name: /sbin/ip6tables-restore < /etc/iptables/rules.v6
    - watch:
      - file: /etc/iptables/rules.v6

/etc/iptables/rules.v4:
  file.managed:
    - source: salt://firewall/rules.v4.tmpl
    - template: jinja

/etc/iptables/rules.v6:
  file.managed:
    - source: salt://firewall/rules.v6.tmpl
    - template: jinja

#
# /etc/network/interfaces
#

ifupdown2:
  pkg.installed


# ifupdown2 configuration
/etc/network/ifupdown2/ifupdown2.conf:
  file.managed:
    - source: salt://network/ifupdown2.conf
    - require:
      - pkg: ifupdown2


# Write network configuration
/etc/network/interfaces:
 file.managed:
    - template: jinja
    - source: salt://network/interfaces/interfaces.tmpl
    - require:
      - pkg: ifupdown2


# Reload interface configuration if neccessary
ifreload:
  cmd.wait:
    - name: /sbin/ifreload -a
    - watch:
      - file: /etc/network/interfaces
    - require:
      - file: /etc/network/ifupdown2/ifupdown2.conf

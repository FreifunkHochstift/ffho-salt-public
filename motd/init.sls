#
# motd
#

{% set name = grains.id.split('.') %}
motd:
  pkg.installed:
    - pkgs:
      - figlet

  cmd.run:
    - name: echo > /etc/motd.freifunk ; figlet {{name[0]}} >> /etc/motd.freifunk; sed -i -e 's/^\(.*\)/     \1/' /etc/motd.freifunk ; sed -i -e '$s/\(.*\)/\1.{{name[1:]|join('.')}}/' /etc/motd.freifunk ; echo >> /etc/motd.freifunk
    - creates: /etc/motd.freifunk

  file.symlink:
    - name: /etc/motd
    - target: /etc/motd.freifunk
    - force: True
    - backupname: /etc/motd.old

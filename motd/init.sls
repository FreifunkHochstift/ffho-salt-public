#
# motd
#

{% set name = grains.id.split('.') %}
motd:
  pkg.installed:
    - pkgs:
      - figlet

  cmd.run:
    - name: echo > /etc/motd.ffmuc ; figlet {{name[0]}} >> /etc/motd.ffmuc; sed -i -e 's/^\(.*\)/     \1/' /etc/motd.ffmuc ; sed -i -e '$s/\(.*\)/\1.{{name[1:]|join('.')}}/' /etc/motd.ffmuc ; echo >> /etc/motd.ffmuc
    - creates: /etc/motd.ffmuc

  file.symlink:
    - name: /etc/motd
    - target: /etc/motd.ffmuc
    - force: True
    - backupname: /etc/motd.old

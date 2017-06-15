#
# motd
#

{% set name = grains.id.split('.') %}
motd:
  pkg.installed:
    - pkgs:
      - figlet

  cmd.run:
    - name: echo > /etc/motd.ffho ; figlet {{name[0]}} >> /etc/motd.ffho; sed -i -e 's/^\(.*\)/     \1/' /etc/motd.ffho ; sed -i -e '$s/\(.*\)/\1.{{name[1:]|join('.')}}/' /etc/motd.ffho ; echo >> /etc/motd.ffho
    - creates: /etc/motd.ffho

  file.symlink:
    - name: /etc/motd
    - target: /etc/motd.ffho
    - force: True
    - backupname: /etc/motd.old

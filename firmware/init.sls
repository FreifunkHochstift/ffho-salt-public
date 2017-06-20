#
# firmware
#

firmware-pkgs:
  pkg.installed:
    - pkgs:
      - git
      - pandoc
  user.present:
    - name: firmware
    - shell: /bin/bash
    - home: /home/firmware
    - createhome: True
    - gid_from_name: True

firmware-git:
  file.directory:
    - name: {{salt['pillar.get']('nodes:' ~ grains['id'] ~ ':path:firmware', [])}}
    - user: firmware
    - group: firmware
    - mode: 755
    - require:
      - user: firmware
  git.latest:
    - name: gogs@git.ffho.net:FreifunkHochstift/ffho-firmware-website.git
    - target: {{salt['pillar.get']('nodes:' ~ grains['id'] ~ ':path:firmware', [])}}
    - user: firmware
    - update_head: False
    - require:
      - pkg: firmware-pkgs
      - user: firmware
      - file: firmware-git

firmware-changelog:
  cmd.run:
    - name: FORCE=1 /usr/local/sbin/update-firmware
    - creates: {{salt['pillar.get']('nodes:' ~ grains['id'] ~ ':path:firmware', [])}}/stable/Changelog.html
    - user: firmware
    - group: firmware
    - watch:
      - git: firmware-git
    - require:
      - user: firmware
      - file: /usr/local/sbin/update-firmware

firmware-cron:
  cron.present:
    - name: /usr/local/sbin/update-firmware
    - identifier: firmware-cron
    - user: firmware
    - minute: 42
    - require:
      - user: firmware
      - file: /usr/local/sbin/update-firmware


/usr/local/sbin/update-firmware:
  file.managed:
    - source: salt://firmware/update-firmware
    - template: jinja
    - mode: 755

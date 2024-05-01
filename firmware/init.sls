#
# firmware
#
{% set firmware_path = salt['pillar.get']('node:path:firmware')

firmware-pkgs:
  pkg.installed:
    - pkgs:
      - git
      - pandoc
  user.present:
    - name: firmware
    - gid: firmware
    - shell: /bin/bash
    - home: /home/firmware
    - createhome: True

firmware-git:
  file.directory:
    - name: {{ firmware_path }}
    - user: firmware
    - group: firmware
    - mode: 755
    - require:
      - user: firmware
  git.latest:
    - name: gogs@git.srv.in.ffho.net:FreifunkHochstift/ffho-firmware-website.git
    - target: {{ firmware_path }}
    - user: firmware
    - update_head: False
    - require:
      - pkg: firmware-pkgs
      - user: firmware
      - file: firmware-git

firmware-changelog:
  cmd.run:
    - name: FORCE=1 /usr/local/sbin/update-firmware
    - creates: {{ firmware_path }}/stable/Changelog.html
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

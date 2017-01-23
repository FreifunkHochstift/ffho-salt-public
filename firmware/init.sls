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
    - name: git@git.c3pb.de:freifunk-pb/firmware-website.git
    - target: {{salt['pillar.get']('nodes:' ~ grains['id'] ~ ':path:firmware', [])}}
    - user: firmware
    - update_head: False
    - require:
      - pkg: firmware-pkgs
      - user: firmware
      - file: firmware-git
      - file: /home/firmware/.ssh/id_rsa
      - ssh_known_hosts: git.c3pb.de

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

# SSH fingerprint of gitlab
git.c3pb.de:
  ssh_known_hosts.present:
    - user: firmware
    - enc: ecdsa
    - fingerprint: 60:97:30:24:0b:85:21:e4:c3:49:c2:f5:12:de:1c:da

/home/firmware/.ssh:
  file.directory:
    - user: firmware
    - group: firmware
    - mode: 700
    - require:
      - user: firmware

/home/firmware/.ssh/authorized_keys:
  file.managed:
    - contents_pillar: nodes:masterbuilder.in.ffho.net:ssh:build:ssh_pubkey
    - user: firmware
    - group: firmware
    - mode: 644
    - require:
      - file: /home/firmware/.ssh

/home/firmware/.ssh/id_rsa:
  file.managed:
    - contents_pillar: nodes:{{ grains['id'] }}:ssh:firmware:ssh_privkey
    - user: firmware
    - group: firmware
    - mode: 400
    - require:
      - file: /home/firmware/.ssh

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

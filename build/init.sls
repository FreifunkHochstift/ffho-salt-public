#
# build
#

build:
  pkg.installed:
    - pkgs:
      - git
      - python
      - subversion
      - build-essential
      - gawk
      - unzip
      - libncurses-dev
      - libz-dev
      - libssl-dev
      - lua5.1
  user.present:
    - name: build
    - shell: /bin/bash
    - home: /home/build
    - createhome: True
    - gid_from_name: True
    - require:
      - group: build
  group.present:
    - name: build
    - system: False

/home/build/.vimrc:
  file.managed:
    - source: salt://vim/vimrc
    - require:
      - user: build

/home/build/.bashrc:
  file.managed:
      - source: salt://bash/bashrc.user
      - template: jinja
      - require:
        - user: build

git-config:
  file.managed:
    - name: /home/build/.gitconfig
    - source: salt://build/gitconfig.build
    - user: build
    - group: build
    - require:
      - user: build

build-git:
  file.directory:
    - name: /srv/build
    - user: build
    - group: build
    - mode: 755
    - require:
      - user: build
  git.latest:
    - name: git@git.c3pb.de:freifunk-pb/firmware.git
    - target: /srv/build
    - user: build
    - update_head: False
    - require:
      - pkg: build
      - user: build
      - ssh_known_hosts: git.c3pb.de
      - file: /home/build/.ssh/id_rsa
      - file: build-git

firmware-git:
  file.directory:
    - name: /srv/build/output
    - user: build
    - mode: 755
    - require:
      - git: build-git
  git.latest:
    - name: git@git.c3pb.de:freifunk-pb/firmware-website.git
    - target: /srv/build/output
    - branch: signing
    - user: build
    - update_head: False
    - require:
      - file: firmware-git

/srv/build/opkg-keys:
  file.directory:
    - user: build
    - group: build
    - mode: 700
    - require:
      - git: build-git

/srv/build/opkg-keys/key-build:
  file.managed:
    - contents_pillar: nodes:{{ grains['id'] }}:opkg:build:privkey
    - user: build
    - group: build
    - mode: 400
    - require:
      - file: /srv/build/opkg-keys

/srv/build/opkg-keys/key-build.pub:
  file.managed:
    - contents_pillar: nodes:{{ grains['id'] }}:opkg:build:pubkey
    - user: build
    - group: build
    - mode: 400
    - require:
      - file: /srv/build/opkg-keys

git.c3pb.de:
  ssh_known_hosts.present:
    - user: build
    - enc: ecdsa
    - fingerprint: 60:97:30:24:0b:85:21:e4:c3:49:c2:f5:12:de:1c:da
    - require:
      - user: build

firmware.in.ffho.net:
  ssh_known_hosts.present:
    - user: build
    - enc: ecdsa
    - fingerprint: {{salt['pillar.get']('nodes:firmware.in.ffho.net:ssh:fingerprint',[])}}
    - require:
      - user: build

/home/build/.ssh:
  file.directory:
    - user: build
    - group: build
    - mode: 700
    - require:
      - user: build

# Create authorized_keys for build
/home/build/.ssh/authorized_keys:
  file.managed:
    - source: salt://ssh/authorized_keys.tmpl
    - template: jinja
      username: build
    - user: build
    - group: build
    - mode: 644
    - require:
      - file: /home/build/.ssh

/home/build/.ssh/id_rsa:
  file.managed:
    - contents_pillar: nodes:{{ grains['id'] }}:ssh:build:privkey
    - user: build
    - group: build
    - mode: 400
    - require:
      - file: /home/build/.ssh

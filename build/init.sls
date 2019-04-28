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
      - rsync
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
    - name: gogs@git.ffho.net:FreifunkHochstift/ffho-firmware-build.git
    - target: /srv/build
    - user: build
    - update_head: False
    - require:
      - pkg: build
      - user: build
      - file: build-git

firmware-git:
  file.directory:
    - name: /srv/build/output
    - user: build
    - mode: 755
    - require:
      - git: build-git
  git.latest:
    - name: gogs@git.ffho.net:FreifunkHochstift/ffho-firmware-website.git
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

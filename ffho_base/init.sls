#
# Stuff for every f*cking FFHO machine
#

ffho_packages:
  pkg.installed:
    - pkgs:
      - git
      - openssl
      - netcat-openbsd


# SSH fingerprint of gitlab on git.c3pb.de
git.c3pb.pubkey:
  ssh_known_hosts:
    - name: git.c3pb.de
    - present
    - user: root
    - enc: ecdsa
    - fingerprint: 60:97:30:24:0b:85:21:e4:c3:49:c2:f5:12:de:1c:da


/usr/local/bin/ff_log_to_bot:
  file.managed:
    - source: salt://ffho_base/ff_log_to_bot
    - template: jinja
    - mode: 755

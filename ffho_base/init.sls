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
    - fingerprint: 51:2a:f4:f4:71:c8:69:8c:96:db:54:b7:f0:36:e5:60


/usr/local/bin/ff_log_to_bot:
  file.managed:
    - source: salt://ffho_base/ff_log_to_bot
    - template: jinja
    - mode: 755

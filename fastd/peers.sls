#
# FFPB Gateways specific stuff
#

# include ffpb stuff (git.c3pb.pubkey, ffpb.id_rsa)
include:
  - ffho_base
  - keys

# Pull fastd mesh peers git
peers-git:
  git.latest:
    - name: git@git.c3pb.de:freifunk-sensitive/knoten.git
    - target: /etc/freifunk/peers
    - rev: master
    - identity: /root/.ssh/ffho_peers_git.id_rsa
    - user: root
    - require:
      - ssh_known_hosts: git.c3pb.pubkey
      - file: /root/.ssh/ffho_peers_git.id_rsa

# Update script
/usr/local/sbin/ff_update_peers:
  file.managed:
    - source: salt://fastd/ff_update_peers
    - user: root
    - group: root
    - mode: 744

## update cronjob
#/etc/cron.d/ff_update_peers:
#  file.managed:
#    - source: salt://fastd/ff_update_peers.cron
#

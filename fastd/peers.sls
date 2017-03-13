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
fastd-update-peers:
  cron.present:
    - name: /usr/local/sbin/ff_update_peers 2>&1 | /usr/local/bin/ff_log_to_bot
    - identifier: fastd-update-peers
    - user: root
    - minute: '*/5'
    - require:
      - file: /usr/local/sbin/ff_update_peers
      - git: peers-git

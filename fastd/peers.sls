#
# FFHO Gateways specific stuff
#

# include ffho stuff (ffho.id_rsa)
include:
  - ffho_base
  - keys

# publish blacklist
/etc/fastd/peers-blacklist:
  file.managed:
    - source: salt://fastd/peers-blacklist
    - user: root
    - group: root
    - mode: 644

/etc/fastd/verify-peer.sh:
  file.managed:
    - source: salt://fastd/verify-peer.sh
    - user: root
    - group: root
    - mode: 744

# Pull fastd mesh peers git
peers-git:
  git.latest:
    - name: gogs@git.ffho.net:ffho-sensitive/ffho-knoten.git
    - target: /etc/freifunk/peers
    - rev: master
    - identity: /root/.ssh/ffho_peers_git.id_rsa
    - user: root
    - require:
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

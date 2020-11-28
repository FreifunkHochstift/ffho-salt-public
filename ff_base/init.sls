#
# Stuff for every FFMUC machine
#

ffmuc_packages:
  pkg.installed:
    - pkgs:
      - git
      - openssl
      - netcat-openbsd
      - htop
      - tcpdump
      - pv
      - wget
      - iftop
      - screen
      - ethtool
      - mtr-tiny
      - lldpd
      - mlocate
      - sysstat
      - dnsutils
      - curl
      - iftop
      - iptraf
      - speedtest-cli
      - dmidecode
      - psmisc
      - lshw

ffmuc_removed_packages:
  pkg.removed:
    - pkgs:
      - postfix
      - rpcbind

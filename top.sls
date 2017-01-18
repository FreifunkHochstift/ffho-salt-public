base:
  # Base config for all minions
  '*':
    - ffinfo
    - apt
    - bash
    - cert.x509
    - console-tools
    - kernel
    - locales
    - mosh
    - network
    - ntp
    - postfix
    - screen
    - snmpd
    - ssh
    - sysctl
    - vim
    - unattended-upgrades

#    - ffpb
#    - monitoring.node
#    - tinc

#
# Roles
#

# Roles no relevant here are
# - batman_gw (require role "batman")
# - bbr (require role "router")

  # Router
  nodes:{{ grains['id'] }}:roles:router:
    - match: pillar
    - bird

  # Batman node?
  nodes:{{ grains['id'] }}:roles:batman:
    - match: pillar
    - batman

  # BRAS / Fastd
  nodes:{{ grains['id'] }}:roles:fastd:
    - match: pillar
    - fastd

  # Hardware nodes
  virtual:physical:
    - match: grain
    - hardware

  # KVM hosts
  nodes:{{ grains['id'] }}:roles:kvm:
    - match: pillar
    - kvm

  # Authoritive DNS server
  nodes:{{ grains['id'] }}:roles:dns-auth:
    - match: pillar
    - dns-server.auth


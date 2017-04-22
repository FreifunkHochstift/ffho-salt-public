base:
  # Base config for all minions
  '*':
    - ffinfo
    - apt
    - bash
    - certs
    - console-tools
    - icinga2
    - kernel
    - locales
    - mosh
    - network
    - ntp
    - postfix
    - rsyslog
    - screen
    - snmpd
    - ssh
    - sysctl
    - vim
    - unattended-upgrades

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

  # Batman node
  nodes:{{ grains['id'] }}:roles:batman:
    - match: pillar
    - batman
    - respondd

  # Batman gateway
  nodes:{{ grains['id'] }}:roles:batman_gw:
    - match: pillar
    - dhcp-server

  # BRAS / Fastd
  nodes:{{ grains['id'] }}:roles:fastd:
    - match: pillar
    - fastd

  # Grafana
  nodes:{{ grains['id'] }}:roles:grafana:
    - match: pillar
    - grafana

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

  # Webfrontend
  nodes:{{ grains['id'] }}:roles:frontend:
    - match: pillar
    - nginx

  # DSL / PPPoE
  nodes:{{ grains['id'] }}:roles:pppoe:
    - match: pillar
    - pppoe

  # InfluxDB
  nodes:{{ grains['id'] }}:roles:influxdb:
    - match: pillar
    - influxdb

  # yanic
  nodes:{{ grains['id'] }}:roles:yanic:
    - match: pillar
    - yanic

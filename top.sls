base:
  # Base config for all minions
  '*':
    - ffinfo
    - apt
    - bash
    - certs
    - icinga2
    - kernel
    - locales
    - mosh
    - motd
    - needrestart
    - nftables
    - network
    - ntp
    - postfix
    - prometheus-exporters
    - rsyslog
    - salt-minion
    - screen
    - snmpd
    - ssh
    - sysctl
    - systemd
    - timezone
    - users
    - vim
    - unattended-upgrades
    - utils

#
# Roles
#

  # Router
  nodes:{{ grains['id'] }}:roles:router:
    - match: pillar
    - bird

  # acme
  nodes:{{ grains['id'] }}:roles:acme:
    - match: pillar
    - acme

  # Batman node
  nodes:{{ grains['id'] }}:roles:batman:
    - match: pillar
    - batman
    - respondd

  # Batman gateway
  nodes:{{ grains['id'] }}:roles:batman_gw:
    - match: pillar
    - dhcp-server

  # Build-Server
  nodes:{{ grains['id'] }}:roles:build:
    - match: pillar
    - build

  # burp client/server
  nodes:{{ grains['id'] }}:tags:backup:
    - match: pillar
    - burp.client

  nodes:{{ grains['id'] }}:roles:burp.server:
    - match: pillar
    - burp.server

  # Fastd
  nodes:{{ grains['id'] }}:roles:fastd:
    - match: pillar
    - fastd

  # Grafana
  nodes:{{ grains['id'] }}:roles:grafana:
    - match: pillar
    - grafana

  # gogs
  nodes:{{ grains['id'] }}:roles:gogs:
    - match: pillar
    - gogs

  # graylog
  nodes:{{ grains['id'] }}:roles:graylog:
    - match: pillar
    - graylog

  # icingaweb2
  nodes:{{ grains['id'] }}:roles:icinga2server:
    - match: pillar
    - icingaweb2

  # KVM hosts
  nodes:{{ grains['id'] }}:roles:kvm:
    - match: pillar
    - kvm

  # (Authoritive?) DNS server
  nodes:{{ grains['id'] }}:roles:dns-server:
    - match: pillar
    - dns-server

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

  # webserver
  nodes:{{ grains['id'] }}:roles:webserver:
    - match: pillar
    - nginx

  # yanic
  nodes:{{ grains['id'] }}:roles:yanic:
    - match: pillar
    - yanic

  # Docker
  nodes:{{ grains['id'] }}:roles:docker:
    - match: pillar
    - docker

  # LibreNMS
  nodes:{{ grains['id'] }}:roles:librenms:
    - match: pillar
    - librenms

  # Promtheus
  nodes:{{ grains['id'] }}:roles:prometheus:
    - match: pillar
    - prometheus-server

  # Anycasted infrastructure services
  nodes:{{ grains['id'] }}:role:infra-services:
    - match: pillar
    - anycast-healthchecker
    - dns-server
    - slapd
    - nginx
    - install-server

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
    - network
    - nftables
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
  node:roles:router:
    - match: pillar
    - bird

  # acme
  node:roles:acme:
    - match: pillar
    - acme

  # Batman node
  node:roles:batman:
    - match: pillar
    - batman
    - respondd

#  # Batman gateway
#  node:roles:batman_gw:
#    - match: pillar
#    - dhcp-server

  # Build-Server
  node:roles:build:
    - match: pillar
    - build

  # burp client/server
  node:tags:backup:
    - match: pillar
    - burp.client

  node:roles:burp.server:
    - match: pillar
    - burp.server

  # Fastd
  node:roles:fastd:
    - match: pillar
    - fastd

  # Grafana
  node:roles:grafana:
    - match: pillar
    - grafana

  # gogs
  node:roles:gogs:
    - match: pillar
    - gogs

  # graylog
  node:roles:graylog:
    - match: pillar
    - graylog

  # icingaweb2
  node:roles:icinga2server:
    - match: pillar
    - icingaweb2

  # KVM hosts
  node:roles:kvm:
    - match: pillar
    - kvm

  # (Authoritive?) DNS server
  node:roles:dns-server:
    - match: pillar
    - dns-server

  # Webfrontend
  node:roles:frontend:
    - match: pillar
    - nginx

  # DSL / PPPoE
  node:roles:pppoe:
    - match: pillar
    - pppoe

  # InfluxDB
  node:roles:influxdb:
    - match: pillar
    - influxdb

  # webserver
  node:roles:webserver:
    - match: pillar
    - nginx

  # yanic
  node:roles:yanic:
    - match: pillar
    - yanic

  # Docker
  node:roles:docker:
    - match: pillar
    - docker

  # LibreNMS
  node:roles:librenms:
    - match: pillar
    - librenms

  # Promtheus
  node:role:prometheus-server:
    - match: pillar
    - grafana
    - prometheus-server
    - nginx

  # Anycasted infrastructure services
  node:role:infra-services:
    - match: pillar
    - anycast-healthchecker
    - dns-server
    - slapd
    - nginx
    - install-server

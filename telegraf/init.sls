###
# Telegraf
###

{% if salt['pillar.get']('netbox:config_context:influxdb', False) %}
{# There is data available so we think telegraf should be installed #}

influxdb-repo:
  pkgrepo.managed:
    - humanname: Jitsi Repo
    - name: deb https://repos.influxdata.com/debian {{ grains.oscodename }} stable
    - file: /etc/apt/sources.list.d/influxdb.list
    - key_url: https://repos.influxdata.com/influxdb.key

telegraf:
  pkg.installed:
    - require:
        - pkgrepo: influxdb-repo
  service.running:
    - enable: True
    - running: True

/etc/telegraf/telegraf.conf:
  file.managed:
    - source: salt://telegraf/files/telegraf.conf

/etc/telegraf/telegraf.d/in-dhcpd-pool-stats.conf:
{% if 'gateway' in salt['pillar.get']('netbox:role:name') or 'nextgen-gateway' in salt['pillar.get']('netbox:role:name') %}
  file.managed:
    - source: salt://telegraf/files/in_dhcpd-pool.conf
{% else %}
  file.absent:
{% endif %}
    - watch_in:
          service: telegraf

/etc/telegraf/telegraf.d/in-dnsdist.conf:
{% if 'dnsdist' in salt['pillar.get']('netbox:config_context:roles') %}
  file.managed:
    - contents: |
        [[inputs.prometheus]]
          urls = ["http://{{ salt["pillar.get"]("netbox:config_context:dnsdist:webserver:bind", "localhost") }}/metrics"]
          username = '{{ salt["pillar.get"]("netbox:config_context:dnsdist:webserver:username", "metrics-collect") }}'
          password = '{{ salt["pillar.get"]("netbox:config_context:dnsdist:webserver:passwort", "secret") }}'
{% else %}
  file.absent:
{% endif %}
    - watch_in:
          service: telegraf

/etc/telegraf/telegraf.d/in-powerdns-recursor.conf:
{%- if 'gateway' in salt['pillar.get']('netbox:role:name') or 'nextgen-gateway' in salt['pillar.get']('netbox:role:name') %}
  file.managed:
    - source: salt://telegraf/files/in_powerdns_recursor.conf
{% else %}
  file.absent:
{% endif %}
    - watch_in:
          service: telegraf

/etc/telegraf/telegraf.d/in-jvb-stats.conf:
{% if salt['pillar.get']('netbox:config_context:videobridge:enabled', False) %}
  file.managed:
    - source: salt://telegraf/files/in_jitsi-videobridge.conf
{% else %}
  file.absent:
{% endif %}
    - watch_in:
          service: telegraf

/etc/telegraf/telegraf.d/in-nginx.conf:
{% if 'webserver-external' in salt['pillar.get']('netbox:role:name') %}
  file.managed:
    - contents: |
        [[inputs.nginx]]
          urls = ["http://localhost:8012/server_status"]
          response_timeout = "5s"
{% else %}
  file.absent:
{% endif %}
    - watch_in:
          service: telegraf

/etc/telegraf/telegraf.d/in-gateway-modules.conf:
{% if 'gateway' in salt['pillar.get']('netbox:role:name') or 'nextgen-gateway' in salt['pillar.get']('netbox:role:name') %}
  file.managed:
    - contents: |
        [[inputs.conntrack]]
          files = ["ip_conntrack_count","ip_conntrack_max", "nf_conntrack_count","nf_conntrack_max"]
          dirs = ["/proc/sys/net/ipv4/netfilter","/proc/sys/net/netfilter"]
        [[inputs.interrupts]]
        [[inputs.linux_sysctl_fs]]
        [[inputs.net]]
        [[inputs.netstat]]
        [[inputs.nstat]]
          proc_net_netstat = "/proc/net/netstat"
          proc_net_snmp = "/proc/net/snmp"
          proc_net_snmp6 = "/proc/net/snmp6"
          dump_zeros       = true
{% else %}
  file.absent:
{% endif %}
    - watch_in:
          service: telegraf

/etc/telegraf/telegraf.d/in-stats.in.ffmuc.net.conf:
{% if 'stats.in.ffmuc.net' == grains.id %}
  file.managed:
    - source: salt://telegraf/files/in_stats.in.ffmuc.net.conf
{% else %}
  file.absent:
{% endif %}
    - watch_in:
        service: telegraf

/etc/telegraf/telegraf.d/in-wireguard.conf:
{%- if 'vpngw' in salt['pillar.get']('netbox:role:name') %}
  file.managed:
    - contents: |
        [[inputs.wireguard]]
{% else %}
  file.absent:
{% endif %}
    - watch_in:
          service: telegraf

/etc/telegraf/telegraf.d/out-influxdb.conf:
  file.managed:
    - source: salt://telegraf/files/out_influxdb.conf
    - template: jinja
    - require_in:
        - service: telegraf
    - watch_in:
        service: telegraf

{% endif %}
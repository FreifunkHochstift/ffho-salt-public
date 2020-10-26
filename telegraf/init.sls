###
# Telegraf
###

{% if salt['pillar.get']('netbox:config_context:influxdb', False) %}
{# There is data available so we think telegraf should be installed #}
{% set role = salt['pillar.get']('netbox:role:name') %}

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
    - template: jinja
    - watch_in:
          service: telegraf

/etc/telegraf/telegraf.d/in-dhcpd-pool-stats.conf:
{% if 'gateway' in role or 'nextgen-gateway' in role %}
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
    - source: salt://telegraf/files/in_dnsdist.conf
    - template: jinja
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
{% if 'webserver-external' in role %}
  file.managed:
    - source: salt://telegraf/files/in_nginx.conf
{% else %}
  file.absent:
{% endif %}
    - watch_in:
          service: telegraf

/etc/telegraf/telegraf.d/in-gateway-modules.conf:
{% if 'gateway' in role or 'nextgen-gateway' in role or 'vpngw' in role %}
  file.managed:
    - source: salt://telegraf/files/in_gateway-modules.conf
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
{%- if 'vpngw' in role %}
  file.managed:
    - source: salt://telegraf/files/in_wireguard.conf
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

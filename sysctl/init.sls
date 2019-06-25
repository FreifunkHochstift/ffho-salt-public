#
# sysctl
#
{% if salt['pillar.get']('netbox:role:name') %}
{%- set role = salt['pillar.get']('netbox:role:name') %}
{% else %}
{%- set role = salt['pillar.get']('netbox:device_role:name') %}
{% endif %}
# Define command to reload sysctl settings here without dependencies
# and define inverse dependencies where useful (see sysctl.conf)
reload-sysctl:
  cmd.wait:
    - watch: []
    - name: /sbin/sysctl --system


/etc/sysctl.conf:
  file.managed:
    - source: salt://sysctl/sysctl.conf
    - watch_in:
      - cmd: reload-sysctl


/etc/sysctl.d/global.conf:
  file.managed:
    - source: salt://sysctl/global.conf
    - watch_in:
      - cmd: reload-sysctl

# Workaround for https://marc.info/?l=oss-security&m=156079308022823&w=2
/etc/sysctl.d/cve-2019-11477.conf:
  file.absent

{% if 'corerouter' in role or 'gateway' in role or 'master' in role or 'out_of_band_mgmt' in role or 'router' in role %}

/etc/sysctl.d/router.conf:
  file.managed:
    - source: salt://sysctl/router.conf
    - watch_in:
      - cmd: reload-sysctl
{% else %}
/etc/sysctl.d/router.conf:
  file.absent
{% endif %}


{# Remove old files #}
{% for file in ['20-arp_caches.conf', '21-ip_forward.conf', '22-kernel.conf', 'NAT.conf', 'nf-ignore-bridge.conf'] %}
/etc/sysctl.d/{{ file }}:
  file.absent
{% endfor %}

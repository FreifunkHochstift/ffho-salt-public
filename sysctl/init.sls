#
# sysctl
#
{% if salt['pillar.get']('netbox:role:name') %}
{%- set role = salt['pillar.get']('netbox:role:name') %}
{% else %}
{%- set role = salt['pillar.get']('netbox:device_role:name') %}
{% endif %}

include:
  - sysctl.global

{% if 'corerouter' in role or 'gateway' in role or 'master' in role or 'out_of_band_mgmt' in role or 'router' in role or 'vpngw' in role or 'docker' in role %}

#
# Activate IP Unicast Routing
net.ipv4.ip_forward:
  sysctl.present:
    - value: 1
    - config: /etc/sysctl.d/21-forwarding.conf

net.ipv6.conf.all.forwarding:
  sysctl.present:
    - value: 1
    - config: /etc/sysctl.d/21-forwarding.conf

{% else %}
net.ipv4.ip_forward:
  sysctl.present:
    - value: 0
    - config: /etc/sysctl.d/21-forwarding.conf

net.ipv6.conf.all.forwarding:
  sysctl.present:
    - value: 0
    - config: /etc/sysctl.d/21-forwarding.conf
{% endif %}


{# Remove old files #}
{% for file in ['20-arp_caches.conf', '21-ip_forward.conf', '22-kernel.conf', 'NAT.conf', 'nf-ignore-bridge.conf', 'global.conf', 'router.conf'] %}
/etc/sysctl.d/{{ file }}:
  file.absent
{% endfor %}

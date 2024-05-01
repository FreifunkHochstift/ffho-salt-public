#
# nftables state
#

{% if not 'no-nftables' in salt['pillar.get']('node:tags', []) %}

nftables:
  pkg.installed:
    - name: nftables
  service.running:
    - enable: true
    - reload: true


/etc/nftables.conf:
  file.managed:
   - source: salt://nftables/nftables.conf.tmpl
   - template: jinja
   - mode: 755
   - require:
     - pkg: nftables
   - watch_in:
     - service: nftables


{% set no_purge_roles = ['docker', 'kvm'] %}
{% set roles = salt['pillar.get']('node:roles', [])%}
{% set not_purge_iptables = salt['ffho.any_item_in_list'](no_purge_roles, roles) %}

purge-iptables:
  pkg.purged:
    - pkgs:
      - iptables-persistent
  {%- if not not_purge_iptables %}
      - iptables
  {%- endif %}

{% endif %}

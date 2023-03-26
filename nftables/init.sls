#
# nftables state
#

{% if not 'no-nftables' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':tags', []) %}

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

purge-iptables:
  pkg.purged:
    - pkgs:
      - iptables-persistent
  {%- if not 'docker' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
      - iptables
  {%- endif %}

{% endif %}

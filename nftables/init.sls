#
# nftables state
#

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

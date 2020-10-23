{% if 'vlan3' in grains['hwaddr_interfaces'] or 'guardian' in grains.id or 'jvb' in grains.id %}
fail2ban-pkg:
  pkg.latest:
    - name: fail2ban

fail2ban-service:
  service.running:
    - name: fail2ban
    - enable: true
    - require: 
      - pkg: fail2ban-pkg
{%endif %}

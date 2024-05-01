#
# sysctl
#
{%- set roles = salt['pillar.get']('node:roles', []) %}

# Define command to reload sysctl settings here without dependencies
# and define inverse dependencies where useful (see sysctl.conf)
reload-sysctl:
  cmd.wait:
    - watch: []
    - name: /sbin/sysctl --system


/etc/sysctl.conf:
  file.managed:
    - source:
      - salt://sysctl/sysctl.conf.{{ grains.os }}.{{ grains.oscodename }}
      - salt://sysctl/sysctl.conf
    - watch_in:
      - cmd: reload-sysctl


/etc/sysctl.d/global.conf:
  file.managed:
    - source: salt://sysctl/global.conf
    - watch_in:
      - cmd: reload-sysctl


{% if 'router' in roles %}
/etc/sysctl.d/router.conf:
  file.managed:
    - source: salt://sysctl/router.conf
    - watch_in:
      - cmd: reload-sysctl
{% else %}
/etc/sysctl.d/router.conf:
  file.absent
{% endif %}

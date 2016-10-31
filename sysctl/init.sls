#
# sysctl
#

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
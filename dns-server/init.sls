#
# Bind name server
#

bind9:
  pkg.installed:
    - name: bind9
  service.running:
    - enable: True
    - reload: True


# Reload command
rndc-reload:
  cmd.wait:
    - watch: []
    - name: /usr/sbin/rndc reload

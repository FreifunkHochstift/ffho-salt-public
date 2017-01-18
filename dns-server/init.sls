#
# Bind name server
#

bind9:
  pkg.installed:
    - name: bind9
  service.running:
    - enable: True
    - reload: True


# Create zones directory
/etc/bind/zones/:
  file.directory:
    - makedirs: true
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: bind9


# Reload command
rndc-reload:
  cmd.wait:
    - watch: []
    - name: /usr/sbin/rndc reload

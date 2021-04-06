#
# Bind name server
#

bind9:
  pkg.installed:
    - name: bind9
  service.running:
    - enable: True
    - reload: True

dns_pkgs:
  pkg.installed:
    - pkgs:
      - python3-dnspython
      - python-dnspython
      - dnsutils
      - bind9-dnsutils

# Reload command
rndc-reload:
  cmd.wait:
    - watch: []
    - name: /usr/sbin/rndc reload

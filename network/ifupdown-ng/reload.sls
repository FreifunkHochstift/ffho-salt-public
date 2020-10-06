#
# network.ifupdown-ng.reload
#

# Reload interface configuration if neccessary (no-op for now)
ifreload:
  cmd.wait:
    - name: /bin/true
    - watch:
      - file: /etc/network/interfaces

#
# Mosh
#

mosh:
  pkg.installed:
    - name: 'mosh'

/etc/ufw/applications.d/mosh:
  file.managed:
    - source: salt://mosh/mosh.ufw.conf

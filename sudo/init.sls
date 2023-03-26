#
# Vim magic
#

sudo:
  pkg.installed:
    - name: sudo

/etc/sudoers.d:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/etc/sudoers:
  file.managed:
    - source:
      - salt://sudo/sudoers.{{ grains.os }}.{{ grains.oscodename }}
      - salt://sudo/sudoers

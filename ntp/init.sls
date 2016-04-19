#
# NTP
#

ntp:
  pkg.installed:
    - name: ntp


/etc/ntp.conf:
  file.managed:
    - source: salt://ntp/ntp.conf

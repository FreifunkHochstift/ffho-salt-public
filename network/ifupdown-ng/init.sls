#
# Use ifupdown-ng to manage the interfaces of this box
#

ifupdown-ng:
  pkg.installed

# ifupdown-ng configuration
/etc/network/ifupdown-ng.conf:
  file.managed:
    - source:
      - salt://network/ifupdown-ng/ifupdown-ng.conf

# Remove workaround for ifupdown2
remove-ifupdown2-workarounds:
  file.absent:
    - name:
      - /usr/local/sbin/ff_fix_default_route
      - /etc/cron.d/ff_fix_default_route

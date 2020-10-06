#
# Use ifupdown2 to manage the interfaces of this box
#

ifupdown2:
  pkg.installed

# ifupdown2 configuration
/etc/network/ifupdown2/ifupdown2.conf:
  file.managed:
    - source:
      - salt://network/ifupdown2/ifupdown2.conf.{{ grains['oscodename'] }}
      - salt://network/ifupdown2/ifupdown2.conf
    - require:
      - pkg: ifupdown2

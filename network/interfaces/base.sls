#
# network.interface.base
#

# Install required packets and write /etc/network/interfaces but don't apply it!

ifupdown2:
  pkg.installed

# ifupdown2 configuration
/etc/network/ifupdown2/ifupdown2.conf:
  file.managed:
    - source:
      - salt://network/ifupdown2.conf.{{ grains['oscodename'] }}
      - salt://network/ifupdown2.conf
    - require:
      - pkg: ifupdown2


# Write network configuration
/etc/network/interfaces:
 file.managed:
    - template: jinja
    - source: salt://network/interfaces/interfaces.tmpl
    - require:
      - pkg: ifupdown2

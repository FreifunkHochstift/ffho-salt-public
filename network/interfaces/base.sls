#
# network.interface.base
#

# Install required packets and write /etc/network/interfaces but don't apply it!

ifupdown2:
  pkg.installed

# Require for some functions of ffho_net module, so make sure they are present.
# Used by functions for bird and dhcp-server for example.
python-network-pkgs:
  pkg.installed:
    - pkgs:
{% if grains.oscodename == "buster" %}
      - python3-ipaddress
{% else %}
      - python-ipaddress
{% endif %}


# ifupdown2 configuration
/etc/network/ifupdown2/ifupdown2.conf:
  file.managed:
    - source:
      - salt://network/ifupdown2.conf.{{ grains['oscodename'] }}
      - salt://network/ifupdown2.conf
    - require:
      - pkg: ifupdown2
      - pkg: python-network-pkgs


# Write network configuration
/etc/network/interfaces:
 file.managed:
    - template: jinja
    - source: salt://network/interfaces/interfaces.tmpl
    - require:
      - pkg: ifupdown2



#
# /etc/network/interfaces
#

ifupdown2:
  pkg.installed

# Require for some functions of ffho_net module, so make sure they are present.
# Used by functions for bird and dhcp-server for example.
python-ipcalc:
  pkg.installed

# ifupdown2 configuration
/etc/network/ifupdown2/ifupdown2.conf:
  file.managed:
    - source: salt://network/ifupdown2.conf
    - require:
      - pkg: ifupdown2
      - pkg: python-ipcalc


# Write network configuration
/etc/network/interfaces:
 file.managed:
    - template: jinja
    - source: salt://network/interfaces/interfaces.tmpl
    - require:
      - pkg: ifupdown2


# Reload interface configuration if neccessary
ifreload:
  cmd.wait:
    - name: /sbin/ifreload -a
    - watch:
      - file: /etc/network/interfaces
    - require:
      - file: /etc/network/ifupdown2/ifupdown2.conf


# If there is an interface in vrf_external, install a workaround script
# for a bug in ifupdown2 which will sometimes drop an IPv4 default route
# present in the kernel and not reinstall it.
#
# The fix script will be called every minute by cron and after ifreload
# was called to try to minimize any downtime.
{% set node_config = salt['pillar.get']('nodes:' ~ grains['id'], {}) %}
{% set sites_config = salt['pillar.get']('sites', {}) %}
{% set ifaces = salt['ffho_net.get_interface_config'](node_config, sites_config) %}
{% if 'vrf_external' in ifaces %}
/usr/local/sbin/ff_fix_default_route:
  file.managed:
    - source: salt://network/interfaces/ff_fix_default_route
    - mode: 755
  cmd.wait:
    - require:
      - cmd: ifreload
    - watch:
      - file: /etc/network/interfaces

/etc/cron.d/ff_fix_default_route:
  file.managed:
    - source: salt://network/interfaces/ff_fix_default_route.cron

{% else %}
/usr/local/sbin/ff_fix_default_route:
  file.absent

/etc/cron.d/ff_fix_default_route:
  file.absent
{% endif %}

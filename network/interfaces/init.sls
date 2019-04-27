#
# /etc/network/interfaces
#

ifupdown2:
  pkg.installed

# Require for some functions of ffho_net module, so make sure they are present.
# Used by functions for bird and dhcp-server for example.
python-ipcalc:
  pkg.installed

# Write network configuration
/etc/network/interfaces:
 file.managed:
    - template: jinja
    - source: salt://network/interfaces/interfaces.tmpl
    - require:
      - pkg: ifupdown2
      - pkg: python-ipcalc


# Reload interface configuration if neccessary
ifreload:
  cmd.wait:
    - name: /sbin/ifreload -a
    - watch:
      - file: /etc/network/interfaces


# If there is an interface in vrf_external, install a workaround script
# for a bug in ifupdown2 which will sometimes drop an IPv4 default route
# present in the kernel and not reinstall it.
#
# The fix script will be called every minute by cron and after ifreload
# was called to try to minimize any downtime.
{% set vrf = False %}
{% if 'vrf_external' in grains['hwaddr_interfaces'] %}
{% set vrf = True %}
{% endif %}
/usr/local/sbin/ff_fix_default_route:
{% if vrf %}
  file.managed:
    - source: salt://network/interfaces/ff_fix_default_route
    - mode: 755
  cmd.wait:
    - require:
      - cmd: ifreload
      - file: /usr/local/sbin/ff_fix_default_route
    - watch:
      - file: /etc/network/interfaces
{% else %}
  file.absent
{% endif %}

/etc/cron.d/ff_fix_default_route:
{% if vrf %}
  file.managed:
    - source: salt://network/interfaces/ff_fix_default_route.cron
{% else %}
  file.absent
{% endif %}

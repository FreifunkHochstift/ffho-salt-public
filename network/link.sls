#
# Networking / link
#

{% if grains['oscodename'] == 'jessie' %}
# Udev rules
/etc/udev/rules.d/42-ffho-net.rules:
  file.managed:
    - template: jinja
    - source: salt://network/udev-rules.tmpl

# Stretch, Buster, ...
{% else %}

# Systemd link files?
  {% for iface, iface_config in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':ifaces', {}).items ()|sort %}
    {% if '_udev_mac' in iface_config or 'mac' in iface_config %}
/etc/systemd/network/42-{{ iface }}.link:
  file.managed:
    - source: salt://network/systemd-link.tmpl
    - template: jinja
      interface: {{ iface }}
      iface_config: {{ iface_config }}
      desc: {{ iface_config.get ('desc', '') }}
    {% endif %}
  {% endfor %}
{% endif %}

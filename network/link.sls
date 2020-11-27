#
# Networking / link
#

# Write an systemd link file for every interface with a MAC
  {% for iface, iface_config in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':ifaces', {}).items ()|sort %}
    {% if 'mac' in iface_config %}
/etc/systemd/network/42-{{ iface }}.link:
  file.managed:
    - source: salt://network/systemd-link.tmpl
    - template: jinja
      interface: {{ iface }}
      iface_config: {{ iface_config }}
      desc: {{ iface_config.get ('desc', '') }}
    - watch_in:
      - cmd: update-initramfs
    {% endif %}
  {% endfor %}

# Rebuild initrd files if neccessary
update-initramfs:
  cmd.wait:
    - name: /usr/sbin/update-initramfs -k all -u

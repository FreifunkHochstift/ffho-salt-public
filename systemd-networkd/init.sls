disable_netplan:
    file.managed:
        - name: /etc/netplan/01-netcfg.yaml 
        - source: salt://systemd-networkd/files/netplan.conf

systemd-networkd:
    service.running:
        - enable: True
        - running: True

generate_initrd:
    cmd.wait:
        - name: update-initramfs -k all -u
        - watch: []

# Rename interfaces to corresponding vlans based on mac address
{%- set interfaces = salt['pillar.get']('netbox:interfaces') %}
{%- set gateway = salt['pillar.get']('netbox:config_context:network:gateway') %}
{% for iface in interfaces |sort %}
{% if "nebula" not in iface %}
{% if 'mac_address' in interfaces[iface] and interfaces[iface]['mac_address'] is not none %}
/etc/systemd/network/42-{{ iface }}.link:
  file.managed:
    - source: salt://systemd-networkd/files/systemd-link.jinja2
    - template: jinja
      interface: {{ iface }}
      mac: {{ interfaces[iface]['mac_address'] }}
      desc: {{ interfaces[iface]['description'] }}
    - watch_in:
          cmd: generate_initrd
{% endif %}
# Generate network files for each interface we have in netbox
/etc/systemd/network/50-{{ iface }}.network:
  file.managed:
    - source: salt://systemd-networkd/files/systemd-network.jinja2
    - template: jinja
      interface: {{ iface }}
      desc: {{ interfaces[iface]['description'] }}
      ipaddresses: {{ interfaces[iface]['ipaddresses'] }}
      gateway: {{ gateway }}

# Are we creating a dummy interface? So we also need a netdev file
{% if "dummy" in iface %}
/etc/systemd/network/50-{{ iface }}.netdev:
  file.managed:
    - source: salt://systemd-networkd/files/systemd-netdev.jinja2
    - template: jinja
      interface: {{ iface }}
      desc: {{ interfaces[iface]['description'] }}
      kind: "dummy"
{% elif "wg" in iface %}
/etc/systemd/network/40-{{ iface }}.netdev:
  file.managed:
    - source: salt://systemd-networkd/files/systemd-netdev.jinja2
    - template: jinja
      interface: {{ iface }}
      desc: {{ interfaces[iface]['description'] }}
      kind: "wireguard"
{% elif "vx" in iface %}
/etc/systemd/network/40-{{ iface }}.netdev:
  file.managed:
    - source: salt://systemd-networkd/files/systemd-netdev.jinja2
    - template: jinja
      interface: {{ iface }}
      desc: {{ interfaces[iface]['description'] }}
      kind: "vxlan"
{% endif %}
{% endif %}
{% endfor %}
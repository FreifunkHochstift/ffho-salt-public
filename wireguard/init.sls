#
# Wireguard VPNs
#
{% set wg_cfg = salt['pillar.get']('node:wireguard', {}) %}


include:
 - sysctl	# Make sure udp_l3mdev_accept is set

# Install wireguard-tools (from backports currently)
wireguard-tools:
  pkg.installed


Create /etc/wireguard:
  file.directory:
    - name: /etc/wireguard
    - require:
      - pkg: wireguard-tools

Cleanup /etc/wireguard:
  file.directory:
    - name: /etc/wireguard
    - clean: true
    # Add cleanup action for active tunnels

{% for iface, tunnel_config in wg_cfg.get ('tunnels', {}).items () %}
/etc/wireguard/{{ iface }}.conf:
  file.managed:
    - source: salt://wireguard/wireguard.conf.tmpl
    - template: jinja
    - context:
      config: {{ tunnel_config }}
      privkey: {{ wg_cfg.get ('privkey') }}
    - require:
      - file: Create /etc/wireguard
    - require_in:
      - file: Cleanup /etc/wireguard
    # start/reload tunnel
{% endfor %}

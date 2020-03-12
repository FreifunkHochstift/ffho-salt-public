{% set interfaces = salt['pillar.get']('netbox:interfaces') %}
python3-netifaces:
  pkg.installed

python3-netaddr:
  pkg.installed

iptables-persistent:
  pkg.installed

netfilter-persistent:
  pkg.installed:
    - name: netfilter-persistent
  service.running:
    - enable: True
    - restart: True

ifreload:
   cmd.wait:
     - name: ifreload -a
     - watch: []

/etc/iptables/rules.v4:
  file.managed:
    - name: /etc/iptables/rules.v4
    - source: salt://wireguard/rules.v4
    - require:
      - pkg: iptables-persistent
      - pkg: netfilter-persistent
    - watch_in:
      - service: netfilter-persistent

bird-configure:
   cmd.wait:
     - name: /usr/sbin/birdc configure 
     - watch: []

bird6-configure:
   cmd.wait:
     - name: /usr/sbin/birdc6 configure
     - watch: []

/etc/wireguard/keys:
    file.directory:
        - name: /etc/wireguard/keys
        - mode: 700
        - user: root
        - group: root

generate-privkey:
    cmd.run:
        - name: 'wg genkey | tee /etc/wireguard/keys/server-priv.key | wg pubkey > /etc/wireguard/keys/server-pub.key'
        - unless: 'test -f /etc/wireguard/keys/server-pub.key'
        - require:
           - file: /etc/wireguard/keys

/etc/bird/bird.d/ebgp.conf:
    file.managed:
        - name: /etc/bird/bird.d/ebgp.conf
        - source: salt://wireguard/ebgp4.jinja2
        - template: jinja
        - defaults:
          interfaces: {{ interfaces }}
        - watch_in:
           - cmd: bird-configure
        - require:
           - pkg: python3-netifaces
           - pkg: python3-netaddr

/etc/bird/bird6.d/ebgp.conf:
    file.managed:
        - name: /etc/bird/bird6.d/ebgp.conf
        - source: salt://wireguard/ebgp6.jinja2
        - template: jinja
        - defaults:
          interfaces: {{ interfaces }}
        - watch_in:
           - cmd: bird6-configure
        - require:
           - pkg: python3-netifaces
           - pkg: python3-netaddr

{% for interface in interfaces | sort %}
{% if 'wg-' in interface %}
{% set client_name = interface.split('wg-')[1] %}

generate-clientkey-{{ interface }}:
    cmd.run:
        - name: 'wg genkey | tee /etc/wireguard/keys/client-{{ client_name }}-priv.key | wg pubkey > /etc/wireguard/keys/client-{{ client_name }}-pub.key'
        - unless: 'test -f /etc/wireguard/keys/client-{{ client_name }}-pub.key'
        - require:
           - file: /etc/wireguard/keys

/etc/wireguard/{{ interface }}.conf:
    file.managed:
        - name: /etc/wireguard/{{ interface }}.conf
        - source: salt://wireguard/wg.jinja2
        - template: jinja
        - defaults:
          interface: {{ interface }}
          interfaces: {{ interfaces }}
          client_name: {{ client_name }}
        - require:
           - cmd: generate-privkey
           - cmd: generate-clientkey-{{ interface }}
        - watch_in:
          - cmd: ifreload

/etc/network/interfaces.d/{{ interface }}:
    file.managed:
        - name: /etc/network/interfaces.d/{{ interface}}
        - source: salt://wireguard/interface.jinja2
        - template: jinja
        - defaults:
          interface: {{ interface }}
          interfaces: {{ interfaces }}
        - watch_in:
          - cmd: ifreload

{% endif %}
{% endfor %}
{% set transfer_prefixes4 = salt['site_prefixes.get_site_prefixes']("", salt['pillar.get']('netbox:config_context:wireguard:transfer_v4')) %}
{% set transfer_prefixes6 = salt['site_prefixes.get_site_prefixes']("", salt['pillar.get']('netbox:config_context:wireguard:transfer_v6')) %}

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
          prefix_4: {{ transfer_prefixes4 }}
          prefix_6: {{ transfer_prefixes6 }}
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
          prefix_4: {{ transfer_prefixes4 }}
          prefix_6: {{ transfer_prefixes6 }}
        - watch_in:
           - cmd: bird6-configure
        - require:
           - pkg: python3-netifaces
           - pkg: python3-netaddr

{% for prefix_name in transfer_prefixes4 %}
{% set interface = prefix_name.split("@")[1] %}

generate-clientkey-{{ interface }}:
    cmd.run:
        - name: 'wg genkey | tee /etc/wireguard/keys/client-{{ interface }}-priv.key | wg pubkey > /etc/wireguard/keys/client-{{ interface }}-pub.key'
        - unless: 'test -f /etc/wireguard/keys/client-{{ interface }}-pub.key'
        - require:
           - file: /etc/wireguard/keys

/etc/wireguard/wg-{{ interface }}.conf:
    file.managed:
        - name: /etc/wireguard/wg-{{ interface }}.conf
        - source: salt://wireguard/wg.jinja2
        - template: jinja
        - defaults:
          interface: {{ interface }}
          prefix_name: {{ prefix_name }}
          prefix_4: {{ transfer_prefixes4 }}
          prefix_6: {{ transfer_prefixes6 }}
        - require:
           - cmd: generate-privkey
           - cmd: generate-clientkey-{{ interface }}

/etc/network/interfaces.d/wg-{{ interface }}:
    file.managed:
        - name: /etc/network/interfaces.d/wg-{{ interface}}
        - source: salt://wireguard/interface.jinja2
        - template: jinja
        - defaults:
          interface: {{ interface }}
          prefix_name: {{ prefix_name }}
          prefix_4: {{ transfer_prefixes4 }}
          prefix_6: {{ transfer_prefixes6 }}


{% endfor %}
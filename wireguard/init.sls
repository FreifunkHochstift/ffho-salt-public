{% set transfer_prefixes4 = salt['site_prefixes.get_site_prefixes']("", salt['pillar.get']('netbox:config_context:wireguard:transfer_v4')) %}
{% set transfer_prefixes6 = salt['site_prefixes.get_site_prefixes']("", salt['pillar.get']('netbox:config_context:wireguard:transfer_v6')) %}

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
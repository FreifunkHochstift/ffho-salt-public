#
# OpenVPN
#

include:
  - certs
  - network.interfaces


openvpn:
  pkg.installed:
    - name: openvpn
    - require:
      - file: /etc/network/interfaces
  service.running:
    - enable: True
    - reload: True


/etc/systemd/system/openvpn@.service:
  file.managed:
    - source: salt://openvpn/openvpn@.service
    - require:
      - pkg: openvpn


/etc/openvpn/ifup:
  file.managed:
    - source: salt://openvpn/ifup
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: openvpn

/etc/openvpn/ifup_real:
  file.managed:
    - source: salt://openvpn/ifup_real
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: openvpn

/etc/openvpn/ifdown:
  file.managed:
    - source: salt://openvpn/ifdown
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: openvpn


# Create 1024 bit DH params, if not present already
/etc/openvpn/dh1024.pem:
  cmd.run:
    - name: openssl dhparam -out /etc/openvpn/dh1024.pem 1024
#    - creates: /etc/openvpn/dh1024.pem
    - unless: ls /etc/openvpn/dh1024.pem


# Create log directory for status log
/var/log/openvpn:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True


# Set up configuration for each and every network configured for this node
{% for netname, network in salt['pillar.get']('ovpn', {}).items () %}
  {% if grains['id'] in network %}
    {% set network_config = network.get ('config') %}
    {% set host_stanza = network.get (grains['id'], {}) %}
    {% set host_config = host_stanza.get ('config', {}) %}
    {# Merge network_config and host_config with host_config inheriting network_config an overwriting options #}
    {% set config = {} %}
    {% for keyword, net_argument in network_config.iteritems () if keyword[0] != '_' %}
      {% do config.update ({ keyword : net_argument }) %}
    {% endfor %}
    {#- If there's a "config:" entry in host YAML without any content it will
    #  wind up as an empty string here. Be kind and silenty handle that.  #}
    {% if host_config is not string or host_config != "" %}
      {% for keyword, host_argument in host_config.items () %}
        {% do config.update ({ keyword : host_argument }) %}
      {% endfor %}
    {% endif %}
    {# END merge #}

# Create systemd start link
openvpn@{{ netname }}:
  service.running:
    - enable: True
    - reload: True
    - require:
      - file: /etc/systemd/system/openvpn@.service
    {% if config.get ('mode', '') == "server" %}
      - file: Cleanup /etc/openvpn/{{ netname }}
    {% endif %}


/etc/openvpn/{{ netname }}.conf:
  file.managed:
    - source: salt://openvpn/openvpn.conf.tmpl
    - template: jinja
    - context:
      netname : {{ netname }}
      network_config: {{ network_config }}
      host_config:    {{ host_config }}
      config:         {{ config }}
    - require:
      - pkg: openvpn
    - watch_in:
      - service: openvpn@{{ netname }}


    {% if config.get ('mode', '') == "server" %}
# Create config dir
Create /etc/openvpn/{{ netname }}:
  file.directory:
    - name: /etc/openvpn/{{ netname }}
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
    - require:
      - pkg: openvpn

Cleanup /etc/openvpn/{{ netname }}:
  file.directory:
    - name: /etc/openvpn/{{ netname }}
    - clean: true

      {% for host, host_stanza in network.items () if not host == 'config' and host != grains['id'] %}
/etc/openvpn/{{ netname }}/{{ host }}:
  file.managed:
    - source: salt://openvpn/ccd.tmpl
    - template: jinja
    - context:
      host_stanza: {{ host_stanza }}
      network_config: {{ network_config }}
    - require:
      - file: Create /etc/openvpn/{{ netname }}
    - require_in:
      - file: Cleanup /etc/openvpn/{{ netname }}

      {% endfor %}
    {% endif %}
  {% endif %}
{% endfor %}

#
# Authoritive FFHO DNS Server configuration (dns01/dns02 anycast)
#

include:
  - dns-server

# Bind options
/etc/bind/named.conf.options:
  file.managed:
    - source: salt://dns-server/auth/named.conf.options
    - template: jinja
    - require:
      - pkg: bind9
    - watch_in:
      - cmd: rndc-reload


# Configure authoritive zones in local config
/etc/bind/named.conf.local:
  file.managed:
    - source: salt://dns-server/auth/named.conf.local
    - require:
      - pkg: bind9
    - watch_in:
      - cmd: rndc-reload


# Create zones directory
/etc/bind/zones/:
  file.directory:
    - makedirs: true
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: bind9

# Create directory for static zone files
/etc/bind/zones/static:
  file.directory:
    - makedirs: true
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: bind9
      - file: /etc/bind/zones/

# Copy zonefiles
/etc/bind/zones/static/_tree:
  file.recurse:
    - name: /etc/bind/zones/static
    - source: salt://dns-server/auth/zones
    - file_mode: 644
    - dir_mode: 755
    - user: root
    - group: root
    - watch_in:
      - cmd: rndc-reload


# Create directory for generated zone files
/etc/bind/zones/generated:
  file.directory:
    - makedirs: true
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: bind9
      - file: /etc/bind/zones/

{% set nodes_config = salt['pillar.get'] ('nodes', {}) %}
{% set sites_config = salt['pillar.get'] ('sites', {}) %}
{% set zones = salt['ffho_net.generate_DNS_entries'] (nodes_config, sites_config) %}
{% for zone, entries in zones.items () %}
/etc/bind/zones/generated/{{ zone }}.zone:
  file.managed:
    - source: salt://dns-server/auth/zone.gen.tmpl
    - template: jinja
    - context:
      zone: {{ zone }}
      nodes_config: {{ nodes_config }}
      sites_config: {{ sites_config }}
    - require:
      - file: /etc/bind/zones/generated
    - watch_in:
      - cmd: rndc-reload
{% endfor %}


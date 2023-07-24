#
# FFHO DNS Server configuration (authoritive / recursive)
#

{% set roles = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}

bind9:
  pkg.installed:
    - name: bind9
  service.running:
    - enable: True
    - reload: True

# Reload command
rndc-reload:
  cmd.wait:
    - watch: []
    - name: /usr/sbin/rndc reload


# Bind options
/etc/bind/named.conf.options:
  file.managed:
{% if 'dns-recursor' in roles %}
    - source: salt://dns-server/named.conf.options.recursor
{% else %}
    - source: salt://dns-server/named.conf.options
{% endif %}
    - template: jinja
    - require:
      - pkg: bind9
    - watch_in:
      - cmd: rndc-reload


# Configure authoritive zones in local config
/etc/bind/named.conf.local:
  file.managed:
    - source: salt://dns-server/named.conf.local
    - template: jinja
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


# Copy static zone files
/etc/bind/zones/static:
  file.recurse:
    - source: salt://dns-server/zones/static/
    - file_mode: 644
    - dir_mode: 755
    - user: root
    - group: root
    - clean: True
    - require:
      - file: /etc/bind/zones/
    - watch_in:
      - cmd: rndc-reload


# Install hybrid zone templates
/etc/bind/zones/hybrid:
  file.recurse:
    - source: salt://dns-server/zones/hybrid/
    - file_mode: 644
    - dir_mode: 755
    - user: root
    - group: root
    - clean: True
    - require:
      - file: /etc/bind/zones/
    - watch_in:
      - cmd: rndc-reload

# Generate node/interface/PTR entries from NetBox
{% set nodes_config = salt['pillar.get'] ('nodes', {}) %}
{% set sites_config = salt['pillar.get'] ('sites', {}) %}
{% set zones = salt['ffho_dns.generate_DNS_entries'] (nodes_config, sites_config) %}

{% for zone, entries in zones.items () %}
/etc/bind/zones/generated/gen{{ zone }}.zone:
  file.managed:
    - source: salt://dns-server/zone.gen.tmpl
    - template: jinja
    - context:
      zone: {{ zone }}
      entries: {{ entries }}
    - require_in:
      - file: Clean /etc/bind/zones/generated
    - watch_in:
      - cmd: rndc-reload
{% endfor %}

Clean /etc/bind/zones/generated:
  file.directory:
    - name: /etc/bind/zones/generated
    - clean: True

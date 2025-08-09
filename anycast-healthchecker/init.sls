#
# Anycast Healthchecker
#

{% set node_roles = salt['pillar.get']('node:roles', []) %}
{% set config = salt['pillar.get']('anycast-healtchecker', {}) %}

include:
  - bird


# Install the package and enable/start the service
anycast-healthchecker:
  pkg.installed:
    - name: anycast-healthchecker
  service.running:
    - enable: True
    - restart: True
    - require:
      - file: /etc/anycast-healthchecker/anycast-healthchecker.conf
      - file: Cleanup /etc/anycast-healthchecker/check.d


# Main configuration
/etc/anycast-healthchecker/anycast-healthchecker.conf:
  file.managed:
    - source: salt://anycast-healthchecker/anycast-healthchecker.conf
    - template: jinja
    - watch_in:
      - service: anycast-healthchecker


# Clean up any previosly configured checks for roles not present anymore
Cleanup /etc/anycast-healthchecker/check.d:
  file.directory:
    - name: /etc/anycast-healthchecker/check.d
    - clean: true

# Configure service checks for any role configured for this node
{%- for srv_by_role, srv_cfg in salt['pillar.get']('anycast-healtchecker:services', {}).items()|sort %}
  {% if srv_by_role not in node_roles %}
    {% continue %}
  {% endif %}
/etc/anycast-healthchecker/check.d/{{ srv_by_role }}.conf:
  file.managed:
    - source: salt://anycast-healthchecker/check.conf.tmpl
    - template: jinja
    - context:
      service: {{ srv_by_role }}
      service_config: {{ srv_cfg }}
    - watch_in:
      - service: anycast-healthchecker
    - require_in:
      - file: Cleanup /etc/anycast-healthchecker/check.d
{%- endfor %}


# Create file /var/lib/anycast-healthchecker/anycast-prefixes-v4.conf is not present
/var/lib/anycast-healthchecker/anycast-prefixes-v4.conf:
  file.managed:
    - user: bird
    # Don't touch file contents when file already is present!
    - replace: False
    - contents: 'define ANYCAST_ADVERTISE = [{{ config['dummy_ip_prefixes'][4] }}];'
    - require:
      - pkg: anycast-healthchecker

/var/lib/anycast-healthchecker/anycast-prefixes-v6.conf:
  file.managed:
    - user: bird
    # Don't touch file contents when file already is present!
    - replace: False
    - contents: 'define ANYCAST_ADVERTISE = [{{ config['dummy_ip_prefixes'][6] }}];'
    - require:
      - pkg: anycast-healthchecker


# Install bird direct protocol for anycast_srv interface
/etc/bird/bird.d/anycast-service.conf:
  file.managed:
    - source: salt://anycast-healthchecker/bird.anycast-service.conf
    - template: jinja
      proto: v4
    - require:
      - pkg: anycast-healthchecker
      - file: /var/lib/anycast-healthchecker/anycast-prefixes-v4.conf
    - watch_in:
      - cmd: bird-configure

/etc/bird/bird6.d/anycast-service.conf:
  file.managed:
    - source: salt://anycast-healthchecker/bird.anycast-service.conf
    - template: jinja
      proto: v6
    - require:
      - pkg: anycast-healthchecker
      - file: /var/lib/anycast-healthchecker/anycast-prefixes-v6.conf
    - watch_in:
      - cmd: bird6-configure

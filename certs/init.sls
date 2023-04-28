#
# SSL Certificates
#

openssl:
  pkg.installed:
    - name: openssl

ssl-cert:
  pkg.installed:
    - name: ssl-cert

update_ca_certificates:
  cmd.wait:
    - name: /usr/sbin/update-ca-certificates
    - watch: []

generate-dhparam:
  cmd.run:
    - name: openssl dhparam -out /etc/ssl/dhparam.pem 2048
    - creates: /etc/ssl/dhparam.pem

# Install FFHO internal CA into Debian CA certificate mangling mechanism so
# libraries (read: openssl) can use the CA cert when validating internal
# service certificates. By installing the cert into the local ca-certificates
# directory and calling update-ca-certificates two symlinks will be installed
# into /etc/ssl/certs which will both point to the crt file:
#  * ffho-cacert.pem
#  * <cn-hash>.pem
# The latter is use by openssl for validation.
/usr/local/share/ca-certificates/ffho-cacert.crt:
  file.managed:
    - source: salt://certs/ffho-cacert.pem
    - user: root
    - group: root
    - mode: 644
    - watch_in:
      - cmd: update_ca_certificates


{% set certs = {} %}

# Are there any certificates defined or referenced in the node pillar?
{% set node_config = salt['pillar.get']('nodes:' ~ grains['id']) %}
{% for cn, cert_config in node_config.get ('certs', {}).items () %}
  {% set pillar_name = None %}

  {# "cert" and "privkey" provided in node config? #}
  {% if 'cert' in cert_config and 'privkey' in cert_config %}
    {% set pillar_name = 'nodes:' ~ grains['id'] ~ ':certs:' ~ cn %}

  {# <cn> only referenced in node config and cert/privkey stored in "cert" pillar? #}
  {% elif cert_config.get ('install', False) == True %}
    {% set pillar_name = 'cert:' ~ cn %}
  {% endif %}

  {% if pillar_name != None %}
    {% do cert_config.update ({ "pillar_name" : pillar_name }) %}
    {% do certs.update ({ cn : cert_config }) %}
  {% endif %}
{% endfor %}

# Are there any cert defined or referenced for this node or roles of this node?
{% set node_roles = node_config.get ('roles', []) %}
{% for cn, cert_config in salt['pillar.get']('cert', {}).items () %}
  {% if grains['id'] in cert_config.get ('apply', {}).get ('node', []) %}
    {% do certs.update ({ cn : { 'pillar_name' : 'cert:' ~ cn }}) %}
  {% endif %}

  {% for role in cert_config.get ('apply', {}).get ('roles', []) %}
    {% if role in node_roles %}
    {% do certs.update ({ cn : { 'pillar_name' : 'cert:' ~ cn }}) %}
    {% endif %}
  {% endfor %}
{% endfor %}

# Install found certificates
{% for cn, cert_config in certs.items () %}
  {% set pillar_name = cert_config['pillar_name'] %}
  {% set user = cert_config.get ('user', 'root') %}
  {% set install_dir = cert_config.get ('install_dir') %}

/etc/ssl/certs/{{ cn }}.cert.pem:
  file.managed:
    {% if salt['pillar.get'](pillar_name ~ ':cert') == "file" %}
    - source: salt://certs/certs/{{ cn }}.cert.pem
    {% else %}
    - contents_pillar: {{ pillar_name }}:cert
    {% endif %}
    {% if install_dir %}
    - name: {{ install_dir }}/{{ cn }}.cert.pem
    {% endif %}
    - user: {{ user }}
    - group: {{ cert_config.get ('group', 'root') }}
    - mode: 644

/etc/ssl/private/{{ cn }}.key.pem:
  file.managed:
    - contents_pillar: {{ pillar_name }}:privkey
    {% if install_dir %}
    - name: {{ install_dir }}/{{ cn }}.key.pem
    {% endif %}
    - user: {{ user }}
    - group: {{ cert_config.get ('group', 'ssl-cert') }}
    - mode: 440
    - require:
      - pkg: ssl-cert
{% endfor %}

{% if 'frontend' in node_config.roles or 'nginx' in node_config %}
certs-nginx-reload:
  cmd.wait:
    - name: service nginx reload
    - watch:
      - file: /etc/ssl/certs/*
{% endif %}

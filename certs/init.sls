#
# SSL Certificates
#

openssl:
  pkg.installed:
    - name: openssl


c_rehash:
  cmd.wait:
    - name: /usr/bin/c_rehash >/dev/null 2>/dev/null
    - watch: []


# FFHO internal CA
/etc/ssl/certs/ffho-cacert.pem:
  file.managed:
    - source: salt://certs/ffho-cacert.pem
    - user: root
    - group: root
    - mode: 644
    - watch_in:
      - cmd: c_rehash


# StartSSL Class1intermediate CA certificate
/etc/ssl/certs/StartSSL_Class1_CA.pem:
  file.managed:
    - source: salt://certs/StartSSL_Class1_CA.pem
    - user: root
    - group: root
    - mode: 644
    - watch_in:
      - cmd: c_rehash


# StartSSL Class2 intermediate CA certificate
/etc/ssl/certs/StartSSL_Class2_CA.pem:
  file.managed:
    - source: salt://certs/StartSSL_Class2_CA.pem
    - user: root
    - group: root
    - mode: 644
    - watch_in:
      - cmd: c_rehash


# Are there any certificates defined or referenced in the node pillar?
{% for cn in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':certs', {})|sort %}
  {% set pillar_name = None %}

  {% set cert_config = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':certs:' ~ cn) %}
  {# "cert" and "privkey" provided in node config? #}
  {% if 'cert' in cert_config and 'privkey' in cert_config %}
    {% set pillar_name = 'nodes:' ~ grains['id'] ~ ':certs:' ~ cn %}

  {# <cn> only referenced in node config and cert/privkey stored in "cert" pillar? #}
  {% elif cert_config.get ('install', False) == True %}
    {% set pillar_name = 'cert:' ~ cn %}
  {% endif %}

  {% if pillar_name != None %}
/etc/ssl/certs/{{ cn }}.cert.pem:
  file.managed:
    - contents_pillar: {{ pillar_name }}:cert
    - user: root
    - group: root
    - mode: 644

/etc/ssl/private/{{ cn }}.key.pem:
  file.managed:
    - contents_pillar: {{ pillar_name }}:privkey
    - user: root
    - group: root
    - mode: 400
  {% endif %}
{% endfor %}

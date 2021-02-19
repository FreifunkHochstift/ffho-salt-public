#
# SSL Certificates
#

openssl:
  pkg.installed:
    - name: openssl

ssl-cert:
  pkg.installed

update_ca_certificates:
  cmd.wait:
    - name: /usr/sbin/update-ca-certificates
    - watch: []

generate-dhparam:
  cmd.run:
    - name: openssl dhparam -out /etc/ssl/dhparam.pem 2048
    - creates: /etc/ssl/dhparam.pem

# Install FFMUC internal CA into Debian CA certificate mangling mechanism so
# libraries (read: openssl) can use the CA cert when validating internal
# service certificates. By installing the cert into the local ca-certificates
# directory and calling update-ca-certificates two symlinks will be installed
# into /etc/ssl/certs which will both point to the crt file:
#  * ffmuc-cacert.pem
#  * <cn-hash>.pem
# The latter is use by openssl for validation.
/usr/local/share/ca-certificates/ffmuc-cacert.crt:
  file.managed:
    - source: salt://certs/ffmuc-cacert.pem
    - user: root
    - group: root
    - mode: 644
    - watch_in:
      - cmd: update_ca_certificates

{%- set cert_validity = salt['cmd.run']('openssl x509 -noout -checkend 2592000 -in /etc/ssl/certs/'~ grains['id']  ~'.cert.pem') %}
{%- if salt["network.ping"]("ca.ov.ffmuc.net", return_boolean=True) %}
{% if 'Certificate will not expire' not in cert_validity %}
{%- set cert_bundle = salt['cfssl_certs.request_cert']('https://ca.ov.ffmuc.net', grains['id']) %}
# Install found certificates
/etc/ssl/certs/{{ grains['id'] }}.cert.pem:
  file.managed:
    - contents: |
        {{ cert_bundle['certificate']|indent(8) }}
    - user: root
    - group: root
    - mode: 644

/etc/ssl/private/{{ grains['id'] }}.key.pem:
  file.managed:
    - contents: |
        {{ cert_bundle['private_key']|indent(8) }}
    - user: root
    - group: ssl-cert
    - mode: 440
    - require:
      - pkg: ssl-cert
{% endif %}{# Certificate wont expire #}
{% endif %}{# can ping ca #}

{%- set role = salt['pillar.get']('netbox:role:name', salt['pillar.get']('netbox:device_role:name')) %}
{% set cloudflare_token = salt['pillar.get']('netbox:config_context:cloudflare:api_token') %}
{% if ("webserver-external" in role or "jitsi meet" in role) and cloudflare_token %}

certbot:
  pkg.installed

python3-pip:
  pkg.installed

acme-client:
  pip.installed:
    - name: acme>=1.8.0
    - require:
      - pkg: python3-pip

certbot-dns-cloudflare:
  pip.installed:
    - require:
      - pkg: python3-pip

dns_credentials:
  file.managed:
    - name: /var/lib/cache/salt/dns_plugin_credentials.ini
    - makedirs: True
    - contents: "dns_cloudflare_api_token = {{ cloudflare_token}}"
    - mode: 600

ffmuc-wildcard-cert:
  acme.cert:
  {% if "webserver-external" in role %}
    - name: ffmuc.net
    - aliases:
        - "*.ffmuc.net"
        - "*.ext.ffmuc.net"
        - "ffmeet.net"
        - "ffmuc.bayern"
        - "*.ffmuc.bayern"
        - "fnmuc.net"
        - "*.fnmuc.net"
        - freie-netze.org
        - "freifunk-muenchen.de"
        - "*.freifunk-muenchen.de"
        - "freifunk-muenchen.net"
        - "*.freifunk-muenchen.net"
        - "xn--freifunk-mnchen-8vb.de"
        - "*.xn--freifunk-mnchen-8vb.de"
  {% else %}{# "jitsi meet" in role #}
    - name: meet.ffmuc.net
    - aliases:
        - "ffmeet.de"
        - "*.ffmeet.de"
        - "ffmeet.net"
        - "*.ffmeet.net"
  {% endif %}
    - email: hilfe@ffmuc.net
    - dns_plugin: cloudflare
    - dns_plugin_credentials: /var/lib/cache/salt/dns_plugin_credentials.ini
    - owner: root
    - group: ssl-cert
    - mode: 0640
    #- renew: True
    - require:
        - pkg: certbot
        - pip: certbot-dns-cloudflare
        - pip: acme-client
        - file: dns_credentials

{% endif %}{# if ("webserver-external" in role or "jitsi meet" in role) and cloudflare_token #}

{% if "webfrontend" in grains.id %}
/etc/letsencrypt/archive/:
  file.directory:
    - group: ssl-cert
    - mode: 0750
/etc/letsencrypt/live/:
  file.directory:
    - group: ssl-cert
    - mode: 0750
{% endif %}
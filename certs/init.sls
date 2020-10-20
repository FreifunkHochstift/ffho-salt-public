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

# Install FFHO internal CA into Debian CA certificate mangling mechanism so
# libraries (read: openssl) can use the CA cert when validating internal
# service certificates. By installing the cert into the local ca-certificates
# directory and calling update-ca-certificates two symlinks will be installed
# into /etc/ssl/certs which will both point to the crt file:
#  * ffho-cacert.pem
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
{% if 'Certificate will not expire' not in cert_validity  %}
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
{% endif %}

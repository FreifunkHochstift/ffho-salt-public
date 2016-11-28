#
# Nginx
#

{% set nginx_pkg = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':nginx:pkg', 'nginx') %}

nginx:
  pkg.installed:
    - name: {{nginx_pkg}}
{% if grains['oscodename'] == 'jessie' %}
    - fromrepo: jessie-backports
{% endif %}
  service.running:
    - enable: TRUE
    - reload: TRUE
    - watch:
      - file: /etc/nginx/sites-*
  file.absent:
    - name: /etc/nginx/sites-enabled/default

{% if grains['saltversion'] >= '2014.7.0' %}
nginx-dhparam:
  cmd.run:
    - name: openssl dhparam -out /etc/ssl/dhparam.pem 4096
    - creates: /etc/ssl/dhparam
    - require_in:
      - serivce: nginx
{% endif %}

{% for website in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':nginx:websites', []) %}
/etc/nginx/sites-enabled/{{website}}:
  file.managed:
    - source: salt://nginx/{{website}}
    - template: jinja
    - require:
      - pkg: nginx
{% endfor %}

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

{% if grains['saltversion'] >= '2014.7.0' %}
nginx-dhparam:
  cmd.run:
    - name: openssl dhparam -out /etc/ssl/dhparam.pem 4096
    - creates: /etc/ssl/dhparam.pem
    - require_in:
      - serivce: nginx
{% endif %}


# Install meaningful main configuration (SSL tweaks 'n stuff)
/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://nginx/nginx.conf
    - watch_in:
      - service: nginx


# Disable default configuration
/etc/nginx/sites-enabled/default:
  file.absent:
    - watch_in:
      - service: nginx


# Install website configuration files configured for this node
{% for website in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':nginx:websites', []) %}
/etc/nginx/sites-enabled/{{website}}:
  file.managed:
    - source: salt://nginx/{{website}}
    - template: jinja
    - require:
      - pkg: nginx
    - watch_in:
      - service: nginx
{% endfor %}

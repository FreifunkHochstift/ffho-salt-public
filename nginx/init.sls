#
# Nginx
#

{% set node_config = salt['pillar.get']('nodes:' ~ grains.id) %}
{% set nginx_pkg = node_config.get('nginx:pkg', 'nginx') %}

nginx:
  pkg.installed:
    - name: {{nginx_pkg}}
{% if grains.oscodename in ['jessie'] %}
    - fromrepo: {{ grains.oscodename }}-backports
{% endif %}
  service.running:
    - enable: TRUE
    - reload: TRUE
    - require:
      - pkg: nginx
    - watch:
      - cmd: nginx-configtest

# Add cache directory
nginx-cache:
  file.directory:
    - name: /srv/cache
    - user: www-data
    - group: www-data
    - require:
      - pkg: nginx
    - require_in:
      - cmd: nginx-configtest

# Install meaningful main configuration (SSL tweaks 'n stuff)
/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://nginx/nginx.conf
    - template: jinja
    - watch_in:
      - cmd: nginx-configtest

# Disable default configuration
/etc/nginx/sites-enabled/default:
  file.absent:
    - watch_in:
      - cmd: nginx-configtest

# Install website configuration files configured for this node
{% for website, website_config in node_config.get('nginx', {}).get('websites', {}).items() %}
/etc/nginx/sites-enabled/{{website}}:
  file.managed:
    - source: salt://nginx/{{website}}
    - template: jinja
      config: {{ website_config }}
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest
{% endfor %}

{% if 'frontend' in node_config.get('roles', []) %}
  {% for domain, config in pillar.get('frontend', {}).items()|sort %}
    {% if 'file' in config %}
/etc/nginx/sites-enabled/{{domain}}:
  file.managed:
    - source: salt://nginx/{{config.file}}
    - template: jinja
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest
    {% endif %}
  {% endfor %}

/etc/nginx/sites-enabled/ff-frontend.conf:
  file.managed:
    - source: salt://nginx/ff-frontend.conf
    - template: jinja
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest
{% endif %}

# Test configuration before reload
nginx-configtest:
  cmd.wait:
    - name: /usr/sbin/nginx -t

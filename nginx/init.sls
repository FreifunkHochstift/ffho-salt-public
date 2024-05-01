#
# Nginx
#

include:
 - systemd

{% set node_config = salt['pillar.get']('node') %}
{% set nginx_pkg = node_config.get('nginx:pkg', 'nginx') %}
{% set acme_thumbprint = salt['pillar.get']('acme:thumbprint') %}

nginx:
  pkg.installed:
    - name: {{nginx_pkg}}
  service.running:
    - enable: TRUE
    - reload: TRUE
    - require:
      - pkg: nginx
    - watch:
      - cmd: nginx-configtest

# Add dependecy on network-online.target
/etc/systemd/system/nginx.service.d/override.conf:
  file.managed:
    - makedirs: true
    - source: salt://nginx/service-override.conf
    - watch_in:
      - cmd: systemctl-daemon-reload

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

/etc/nginx/ffho.d:
  file.recurse:
    - source: salt://nginx/ffho.d
    - file_mode: 755
    - dir_mode: 755
    - user: root
    - group: root
    - clean: True
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
      acme_thumbprint: {{ acme_thumbprint }}
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
      acme_thumbprint: {{ acme_thumbprint }}
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

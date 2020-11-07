###
# nginx
###
{%- set role = salt['pillar.get']('netbox:role:name', salt['pillar.get']('netbox:device_role:name')) %}
{% if "webserver" in role %}

/etc/apt/sources.list.d/nginx.list:
  pkgrepo.managed:
    - name: deb http://nginx.org/packages/{{ grains.os | lower}} {{ grains.oscodename }} nginx
    - file: /etc/apt/sources.list.d/nginx.list
    - keyserver: keys.gnupg.net
    - keyid: ABF5BD827BD9BF62

nginx:
  pkg.installed:
    - name: nginx
    - require:
      - pkgrepo: /etc/apt/sources.list.d/nginx.list
  service.running:
    - enable: TRUE
    - reload: TRUE
    - require:
      - pkg: nginx
    - watch:
      - cmd: nginx-configtest

# Test configuration before reload
nginx-configtest:
  cmd.wait:
    - name: /usr/sbin/nginx -t

# Disable default configuration
/etc/nginx/sites-enabled/default:
  file.absent:
    - watch_in:
      - cmd: nginx-configtest

{% if salt["service.available"]("nginx") %}
{% set nginx_version = salt["pkg.info_installed"]("nginx").get("nginx", {}).get("version","").split("-")[0] %}
{% else %}
{% set nginx_version = "1.18.0" %}{# current on 02.11.2020 #}
{% endif %}

{% for module in ["http_brotli_filter_module", "http_brotli_static_module", "http_fancyindex_module"] %}
nginx-module-{{module}}:
  file.managed:
    - name: /usr/lib/nginx/modules/ngx_{{ module }}.so
    - source: https://mirror.krombel.de/nginx-{{ nginx_version }}/ngx_{{ module }}.so
    - skip_verify: True
    - watch_in:
      - cmd: nginx-configtest
{% endfor %}

/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://nginx/files/nginx.conf
    - template: jinja
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest

/etc/nginx/sites-enabled/zz-default.conf:
  file.managed:
    - source: salt://nginx/files/default.conf
    - makedirs: True
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest

# TODO: Make dynamic
{% for domain in [
    "ffmuc.net",
    "byro.ffmuc.net",
    "chat.ffmuc.net",
    "cloud.ffmuc.net",
    "doh.ffmuc.net",
    "map.ffmuc.net",
    "stats.ffmuc.net",
    "tiles.ffmuc.net",
    "tickets.ffmuc.net",
    "unifi.ffmuc.net",
    "stub_status"
] %}
/etc/nginx/sites-enabled/{{ domain }}.conf:
  file.managed:
    - source:
        - salt://nginx/domains/{{ domain }}.conf
        - salt://nginx/files/nginx_vhost.jinja2
    - makedirs: True
    - defaults:
        domain: {{ domain }}
    - template: jinja
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest

{% endfor %}

/etc/nginx/streams-enabled/unifi.conf:
  file.managed:
    - source: salt://nginx/files/unifi_stream.conf
    - makedirs: True
    - require:
      - pkg: nginx
    - watch_in:
      - cmd: nginx-configtest

/etc/nginx/conf.d/log_json.conf:
  file.managed:
    - source: salt://nginx/files/log_json.conf.jinja
    - makedirs: True
    - template: jinja
    - require:
      - pkg: nginx

{% endif %}{# webserver in role #}

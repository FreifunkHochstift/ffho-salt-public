#
# respondd
# Source for template: https://github.com/ffggrz/ext-respondd.git
#

/etc/systemd/system/respondd@.service:
  file.managed:
    - source: salt://respondd/respondd-tmpl/respondd@.service

python3-netifaces:
   pkg.installed

{% for site in salt['pillar.get']('netbox:config_context:sites')  %}

{% if not salt['file.directory_exists']('/opt/respondd-' ~ site ) %}
/opt/respondd-{{ site }}:
  file.recurse:
    - source: salt://respondd/respondd-tmpl
{% endif %}

/opt/respondd-{{site}}/alias.json:
  file.managed:
    - source: salt://respondd/alias.json
    - template: jinja
    - defaults:
      site: {{ site }}

/opt/respondd-{{site}}/config.json:
  file.managed:
    - source: salt://respondd/config.json
    - template: jinja
    - defaults:
      site: {{ site }}

/opt/respondd-{{site}}/lib/respondd_client.py:
  file.managed:
    - source: salt://respondd/respondd-tmpl/lib/respondd_client.py
    - template: jinja
    - defaults:
      site: {{ site }}
      id: {{ salt['pillar.get']('netbox:config_context:site_config:{{ site }}:site_no')  }}


/opt/respondd-{{ site }}/ext-respondd.py:
  file.managed:
    - mode: 0755
    # only to harm the salt gods to not complain with
    # "Neither 'source' nor 'contents' nor 'contents_pillar' nor 'contents_grains' was defined"
    - source: salt://respondd/respondd-tmpl/ext-respondd.py

respondd@{{site}}:
  service.running:
    - enable: True
    - require:
      - file: /opt/respondd-{{site}}/alias.json
      - file: /opt/respondd-{{site}}/config.json
      - file: /etc/systemd/system/respondd@.service
{% endfor %}


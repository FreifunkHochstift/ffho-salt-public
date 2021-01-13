#
# Salt minion config
#

salt-minion:
  pkg.installed:
    - pkgs:
      - salt-minion
{% if grains.oscodename == "buster" %}
      - python3-tornado
{% endif %}
  service.running:
    - enable: true
#    - reload: true

/etc/salt/minion:
  file.managed:
    - source: salt://salt-minion/minion_conf.tmpl
    - template: jinja
    - context:
      salt_config: {{ salt['pillar.get']('globals:salt') }}
    - require:
      - pkg: salt-minion
#    - watch_in:
#      - service: salt-minion

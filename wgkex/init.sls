

{%- if 'nextgen-gateway' in salt['pillar.get']('netbox:role:name') %}

python3-pyroute2:
  pkg.installed

/srv/wgkex:
  git.latest:
    - name: https://github.com/freifunkMUC/wgkex
    - target: /srv/wgkex
    - rev: add_mqtt

# temporary:
/srv/wgkex/wgkex/config/config.py:
  file.managed:
    - source: https://raw.githubusercontent.com/freifunkMUC/wgkex/extend_config_mqtt/wgkex/config/config.py
    - skip_verify: True
    - require:
      - git: /srv/wgkex
    - require_in:
      - service: wgkex-service
    - watch_in: wgkex-service

/etc/systemd/system/wgkex.service:
  file.managed:
    - source: salt://wgkex/wgkex.service

/etc/wgkex.yaml:
  file.managed:
    - source: salt://wgkex/wgkex.yaml

wgkex-service:
  service.running:
    - name: wgkex
    - enable: True
    - require:
        - file: /etc/wgkex.yaml
    - watch:
        - file: /etc/wgkex.yaml

systemd-reload-wgkex:
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:  
      - file: /etc/systemd/system/wgkex.service
    - watch_in:
      - service: wgkex-service

{% endif %}
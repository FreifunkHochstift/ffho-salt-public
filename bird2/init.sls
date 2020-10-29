include:
    - systemd-networkd

install_bird2:
    pkg.installed:
        - name: bird2
    
bird:
    service.running:
        - enable: true
        - running: True

bird2_configure:
  cmd.wait:
    - name: /usr/sbin/birdc configure
    - watch: []

/etc/bird:
  file.directory:
    - mode: 750
    - user: bird
    - group: bird
    - require:
      - pkg: install_bird2

bird2_config:
    file.managed:
        - name: /etc/bird/bird.conf
        - source: salt://bird2/files/bird.conf.jinja2
        - template: jinja
        - require:
            - file: /etc/bird
            - service: systemd-networkd
        - require_in:
            - service: bird
        - watch_in:
            - cmd: bird2_configure
        - mode: 644
        - user: root
        - group: bird

{%- if 'backup' in salt['pillar.get']('netbox:tag_list', []) -%}

{% if 'Raspbian' not in grains.lsb_distrib_id %}
duplicity-packages:
  pkg.installed:
    - pkgs:
      - duplicity
      - gnupg
      - gnupg-agent
      - python3-pip

    - require:
      - pkgrepo: duplicity_repo

duplicity_repo:
  pkgrepo.managed:
    - ppa: duplicity-team/duplicity-release-git
    - keyid: 8F571BB27A86F4A2
    - keyserver: keyserver.ubuntu.com
    - file: /etc/apt/sources.list.d/duplicity.list

b2sdk:
  pip.installed:
    - require:
      - pkg: duplicity-packages
{% endif %}

backup-script:
  file.managed:
    - name: /usr/local/sbin/backup.sh
    - source: salt://duplicity/files/backup.sh.jinja2
    - mode: 0750
    - template: jinja

/etc/systemd/system/ffmuc-backup.service:
  file.managed:
    - source: salt://duplicity/files/ffmuc-backup.service

/etc/systemd/system/ffmuc-backup.timer:
  file.managed:
    - source: salt://duplicity/files/ffmuc-backup.timer

systemd-reload-ffmuc-backup:
  cmd.run:
    - name: systemctl --system daemon-reload
    - onchanges:
      - file: /etc/systemd/system/ffmuc-backup.service
      - file: /etc/systemd/system/ffmuc-backup.timer

ffmuc-backup-timer-enable:
  service.enabled:
    - name: ffmuc-backup.timer
    - require:
      - file: /etc/systemd/system/ffmuc-backup.timer
    - full_restart: True
    - onchanges:
      - file: /etc/systemd/system/ffmuc-backup.timer

{% endif %}{# if backup in tags #}
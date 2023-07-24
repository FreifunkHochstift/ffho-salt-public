#
# yanic
#

# add yanic directory
/srv/yanic/data:
  file.directory:
    - makedirs: True

# copy yanic binary to destination
# the binary needs to be provided by the salt-master
yanic:
  file.managed:
   - name: /srv/yanic/yanic
   - source: salt://yanic/yanic
   - mode: 755
   - require:
     - file: /srv/yanic/data

# copy systemd yanic@.service
/etc/systemd/system/yanic@.service:
  file.managed:
    - source: salt://yanic/yanic@.service
    - require:
      - file: yanic

# get loopback IPv6 for binding the webserver to it
{% set node_config = salt['pillar.get']('nodes:' ~ grains['id']) %}
{% set bind_ip = salt['ffho_net.get_primary_ip'](node_config, 'v6').ip %}

# for each site
{% for site in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':sites', []) %}
# add webserver directory
/srv/yanic/data/{{site}}:
  file.directory:
    - require:
      - file: /srv/yanic/data

# add configuration file
/srv/yanic/{{site}}.conf:
  file.managed:
    - source: salt://yanic/yanic.conf.tmpl
    - template: jinja
    - defaults:
      iface: "br-{{site}}"
      site: "{{site}}"
      webserver: "{{ "true" if loop.first else "false" }}"
      bind_ip: {{bind_ip}}
      influxdb: {{node_config.yanic.influxdb}}
    - require:
      - file: /srv/yanic/data/{{site}}

# enable the yanic service
# and restart if configuration or binary has changed
yanic@{{site}}:
  service.running:
    - enable: True
    - require:
      - file: /srv/yanic/{{site}}.conf
      - file: /etc/systemd/system/yanic@.service
    - watch:
      - file: /srv/yanic/{{site}}.conf
      - file: yanic
{% endfor %}


/usr/local/bin/ff_merge_nodes_json:
  file.managed:
    - source: salt://yanic/ff_merge_nodes_json
    - mode: 755

/etc/cron.d/ff_merge_nodes_json:
  file.managed:
    - source: salt://yanic/ff_merge_nodes_json.cron

# backup yanic data
/srv/yanic/backup.sh:
  file.managed:
    - contents: |
        #!/bin/bash
        YANIC=/srv/yanic
        DATE=$(/bin/date +%Y%m%d-%H%M)
        BACKUP=${YANIC}/backup
        DAYS=7
        mkdir -p ${BACKUP}/${DATE}
        cp ${YANIC}/*.state ${BACKUP}/${DATE}
        find ${BACKUP} -mindepth 1 -mtime +${DAYS} -delete
    - mode: 755 
    - user: root

cron-yanic-backup:
  cron.present:
    - identifier: CRON_YANIC_BACKUP
    - user: root
    - name: /srv/yanic/backup.sh
    - minute: 0
    - hour: "*/12"

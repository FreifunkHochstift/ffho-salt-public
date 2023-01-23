#
# mongodb
#

mongodb-repo:
  pkgrepo.managed:
    - humanname: MongoDB Repo
    - file: /etc/apt/sources.list.d/mongodb-org.list
    - key_url: https://www.mongodb.org/static/pgp/server-{{ mongodb_version }}.asc
    {% if mongodb_version == '4.2' %}
    - name: deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.2 main
    {% elif mongodb_version == '4.4' %}
    - name: deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main
    {% elif mongodb_version == '5.0' %}
    - name: deb http://repo.mongodb.org/apt/debian {{ grains.oscodename }}/mongodb-org/5.0 main
    {% endif %}

mongodb:
  pkg.installed:
    - name: mongodb-org
  service.running:
    - name: mongod
    - enable: True

# Install cronjob, backup script and corresponding config file
/etc/cron.d/mongodb_backup:
  file.managed:
    - source: salt://mongodb/mongodb_backup.cron

/usr/local/sbin/mongodb_backup:
  file.managed:
    - source: salt://mongodb/mongodb_backup
    - mode: 755

/etc/mongodb_backup.conf:
  file.managed:
    - source: salt://mongodb/mongodb_backup.conf
    - mode: 600
    - user: root
    - group: root

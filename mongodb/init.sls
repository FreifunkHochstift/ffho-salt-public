#
# mongodb
#

mongodb-repo-4.2:
  pkgrepo.managed:
    - humanname: MongoDB Repo
    - name: deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.2 main
    - file: /etc/apt/sources.list.d/mongodb-org-4.2.list
    - key_url: https://www.mongodb.org/static/pgp/server-4.2.asc

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

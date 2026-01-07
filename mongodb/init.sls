#
# mongodb
#

mongodb-repo:
  pkgrepo.managed:
    - humanname: MongoDB Repo
    - file: /etc/apt/sources.list.d/mongodb-org.list
    - key_url: https://www.mongodb.org/static/pgp/server-{{ mongodb_version }}.asc
    - name: deb http://repo.mongodb.org/apt/debian {{ grains.oscodename }}/mongodb-org/{{ mongodb_version }} main

mongodb:
  pkg.installed:
    - pkgs:
      - mongodb-org
      - python3-pymongo
  service.running:
    - name: mongod
    - enable: True
    - require:
      - pkg: mongodb
    - watch:
      - file: /etc/mongod.conf

# Create mongodb admin user
mongoadmin:
  mongodb_user.present:
  - name: {{ mongodb_admin_username }}
  - passwd: {{ mongodb_admin_password }}
  - database: admin
  - roles: {{ mongodb_admin_roles }}
  - user: {{ mongodb_admin_username }}
  - password: {{ mongodb_admin_password }}

# Install mongod config, cronjob, backup script and corresponding config file
/etc/mongod.conf:
  file.managed:
    - source: salt://mongodb/mongod.conf
    - require:
      - mongodb_user: mongoadmin

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

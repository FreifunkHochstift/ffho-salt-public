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

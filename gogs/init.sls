#
# gogs
#

{% set config = salt['pillar.get']('nodes:' ~ grains.id ~ ':gogs', {}) %}

gogs-repo:
  pkgrepo.managed:
    - comments: "# gogs repo"
    - human_name: gogs repository
    - name: "deb https://deb.packager.io/gh/pkgr/gogs {{ grains.oscodename }} pkgr"
    - dist: {{grains.oscodename}}
    - file: /etc/apt/sources.list.d/gogs.list
    - key_url: salt://gogs/gogs-repo.apt.key

postgresql:
  pkg.installed:
    - name: postgresql

  service.running:
    - name: postgresql
    - enable: true
    - require:
      - pkg: postgresql

gogs:
  pkg.installed:
    - pkgs:
      - gogs
    - require:
      - pkgrepo: gogs-repo

  postgres_database.present:
    - require:
      - service: postgresql

  postgres_user.present:
    - password: {{config.password}}
    - require:
      - service: postgresql

  postgres_privileges.present:
    - object_name: gogs
    - object_type: database
    - user: postgres
    - privileges:
      - all
    - require:
      - postgres_database: gogs
      - postgres_user: gogs

/srv/gogs:
  file.directory:
    - user: gogs
    - group: gogs
    - require:
      - pkg: gogs

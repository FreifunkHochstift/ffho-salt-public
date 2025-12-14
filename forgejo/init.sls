#
# forgejo
#

{% set config = salt['pillar.get']('node:forgejo', {}) %}

forgejo-repo:
  file.managed:
    - names:
      - /usr/share/keyrings/forgejo-apt.asc:
        - source: salt://forgejo/forgejo-apt.asc

  pkgrepo.managed:
    - comments: "# forgejo repo"
    - human_name: forgejo repository
    - name: "deb [signed-by=/usr/share/keyrings/forgejo-apt.asc] https://code.forgejo.org/api/packages/apt/debian lts main"
    - file: /etc/apt/sources.list.d/forgejo.list

postgresql:
  pkg.installed:
    - name: postgresql

  service.running:
    - name: postgresql
    - enable: true
    - require:
      - pkg: postgresql

forgejo:
  pkg.installed:
    - pkgs:
      - forgejo
    - require:
      - pkgrepo: forgejo-repo

  postgres_database.present:
    - name: forgejo
    - require:
      - service: postgresql

  postgres_user.present:
    - password: {{config.password}}
    - require:
      - service: postgresql

  postgres_privileges.present:
    - object_name: forgejo
    - object_type: database
    - user: postgres
    - privileges:
      - all
    - require:
      - postgres_database: forgejo
      - postgres_user: forgejo

/etc/forgejo/app.ini:
  file.managed:
    - source: salt://forgejo/app.ini.tmpl
    - template: jinja
    - context:
      config: {{ config }}
    - require:
      - pkg: forgejo


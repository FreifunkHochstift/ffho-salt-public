#
# Pressed
#

/srv/provision:
  file.directory

# Debian presseds
/srv/provision/preseed:
  file.directory:
    - require:
      - file: /srv/provision

{% for osrelease in ['bullseye', 'bookworm'] %}
/srv/provision/preseed/apu-{{ osrelease }}.txt:
  file.managed:
    - source: salt://install-server/preseed/apu-{{ osrelease }}.txt
    - template: jinja
    - context:
      provision_fqdn: {{ salt['pillar.get']('globals:provision:webserver_fqdn') }}
    - require:
      - file: /srv/provision/preseed
{% endfor %}

# Conveniece symlink for short http URL
/srv/provision/apu.txt:
  file.symlink:
    - target: /srv/provision/preseed/apu-bullseye.txt
    - require:
      - file: /srv/provision/preseed/apu-bullseye.txt


# Late command downloaded into and run from preseed
/srv/provision/late-command.sh:
  file.managed:
    - source: salt://install-server/late-command.sh.tmpl
    - template: jinja
    - context:
      nacl_url: {{ salt['pillar.get']('globals:nacl:url') }}
      salt_master_fqdn: {{ salt['pillar.get']("globals:salt:master") }}
    - require:
      - file: /srv/provision


# First boot script + service
/srv/provision/ffho-first-boot.sh:
  file.managed:
    - source: salt://install-server/ffho-first-boot.sh
    - require:
      - file: /srv/provision

/srv/provision/ffho-first-boot.service:
  file.managed:
    - source: salt://install-server/ffho-first-boot.service
    - require:
      - file: /srv/provision


# Local copy of NACL CLI tools
Create /srv/provision/nacl:
  file.directory:
    - name: /srv/provision/nacl
    - require:
      - file: /srv/provision

{% for file_name in ['get_fqdn', 'register_ssh_keys'] %}
/srv/provision/nacl/{{ file_name }}:
  file.managed:
    - source: salt://install-server/nacl/{{ file_name }}
    - require:
      - file: Create /srv/provision/nacl
    - require_in:
      - file: Clean /srv/provision/nacl
{% endfor %}

Clean /srv/provision/nacl:
  file.directory:
    - name: /srv/provision/nacl
    - clean: true


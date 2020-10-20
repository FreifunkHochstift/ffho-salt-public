#
# Setup docker.io
#
{%- set role = salt['pillar.get']('netbox:role:name', salt['pillar.get']('netbox:device_role:name')) %}

{% if 'docker' in role or 'mailserver' in role %}
docker-repo:
  pkgrepo.managed:
    - comments: "# Docker.io"
    - human_name: Docker.io repository
    - name: "deb https://download.docker.com/linux/debian {{ grains.oscodename }} stable"
    - dist: {{ grains.oscodename }}
    - file: /etc/apt/sources.list.d/docker.list
    - key_url: https://download.docker.com/linux/debian/gpg

docker-pkgs:
  pkg.latest:
    - pkgs:
      - docker-ce
      - docker-ce-cli
      - containerd.io
    - require:
      - pkgrepo: docker-repo

{# limit log-file-size #}
/etc/docker/daemon.json:
  file.managed:
    - contents: |
        {
          "log-driver": "json-file",
          "log-opts": {
            "max-size": "10m",
            "max-file": "3"
          }
        }
{#
# Install docker-compose via pip *shrug*
python-pip:
  pkg.installed

docker-compose:
  pip.installed:
    - require:
      - pkg: python-pip
#}
{% endif  %}

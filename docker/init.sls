#
# Setup docker.io
#

docker-repo:
  pkgrepo.managed:
    - comments: "# Docker.io"
    - human_name: Docker.io repository
    - name: "deb https://download.docker.com/linux/debian {{ grains.oscodename }} stable"
    - dist: {{ grains.oscodename }}
    - file: /etc/apt/sources.list.d/docker.list
    - key_url: https://download.docker.com/linux/debian/gpg

docker-pkgs:
  pkg.installed:
    - pkgs:
      - docker-ce
      - docker-ce-cli
      - containerd.io

# Install docker-compose via pip *shrug*
python-pip:
  pkg.installed

docker-compose:
  pip.installed:
    - require:
      - pkg: python-pip

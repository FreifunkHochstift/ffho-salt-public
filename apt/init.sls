#
# APT
#

/etc/apt/sources.list:
  file.managed:
    - source: salt://apt/sources.list.{{ grains.os }}.{{ grains.oscodename }}

/etc/apt/sources.list.d/repo_saltstack_com_apt_debian_9_amd64_latest.list:
  file.absent

salt-repo:
  pkgrepo.managed:
    - humanname: SaltStack-
    {% if 'Ubuntu' in grains.lsb_distrib_id %}
    - name: deb http://repo.saltstack.com/py3/{{ grains.lsb_distrib_id | lower }}/{{ grains.osrelease }}/{{ grains.osarch }}/latest {{ grains.oscodename }} main
    {% elif 'Raspbian' in grains.lsb_distrib_id %}
    - name: deb http://repo.saltstack.com/py3/debian/{{ grains.osmajorrelease }}/{{ grains.osarch }}/latest {{ grains.oscodename }} main
    {% else %}
    - name: deb http://repo.saltstack.com/py3/{{ grains.lsb_distrib_id | lower }}/{{ grains.osmajorrelease }}/{{ grains.osarch }}/3000 {{ grains.oscodename }} main
    {% endif %}
    - dist: {{ grains.oscodename }}
    - file: /etc/apt/sources.list.d/saltstack.list
    - clean_file: True

/etc/cron.d/apt:
  file.managed:
    - source: salt://apt/update_apt.cron

apt-transport-https:
  pkg.installed

python-apt:
  pkg.installed

# Purge old stuff
/etc/apt/sources.list.d/raspi.list:
  file.absent

/etc/apt/sources.list.d/universe-factory.list:
  file.absent

/etc/apt/preferences.d/libluajit:
  file.managed:
    - contents: |
        Package: libluajit-5.1-2
        Pin: origin deb.debian.org
        Pin-Priority: 1001

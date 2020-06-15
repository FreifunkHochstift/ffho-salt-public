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
    - humanname: SaltStack-Repo
    - name: deb http://repo.saltstack.com/py3/debian/{{ grains.osmajorrelease }}/{{ grains.osarch }}/3000 {{ grains.oscodename }} main
    - dist: {{ grains.oscodename }}
    - file: /etc/apt/sources.list.d/saltstack.list

/etc/cron.d/apt:
  file.managed:
    - source: salt://apt/update_apt.cron

apt-transport-https:
  pkg.installed

python-apt:
  pkg.installed

{% if grains.oscodename != "buster" %}
ffho-repo:
  pkgrepo.managed:
    - comments:
      - "# FFHO APT repo"
    - human_name: FFHO repository
    - name: deb http://apt.ffho.net/ {{ grains.oscodename }} main contrib non-free
    - clean_file: True
    - dist: {{ grains.oscodename }}
    - file: /etc/apt/sources.list.d/ffho.list
    - keyserver: keys.gnupg.net
{% if grains.oscodename == "jessie" %}
    - keyid: 40FC1CE2
{% else %}
    - keyid: EB88A4D5
{% endif %}
    - require:
      - pkg: python-apt
{% endif %}

# Purge old stuff
/etc/apt/sources.list.d/raspi.list:
  file.absent

/etc/apt/sources.list.d/universe-factory.list:
  file.absent

# APT preferences
/etc/apt/preferences.d/ffho:
  file.managed:
    - source: salt://apt/ffho.preferences

/etc/apt/preferences.d/libluajit:
  file.managed:
    - contents: |
        Package: libluajit-5.1-2
        Pin: origin deb.debian.org
        Pin-Priority: 1001

/etc/apt/apt.conf.d/ffho:
  file.managed:
    - source: salt://apt/ffho.apt.conf

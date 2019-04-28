#
# APT
#

/etc/apt/sources.list:
  file.managed:
    - source: salt://apt/sources.list.{{ grains.os }}.{{ grains.oscodename }}

/etc/cron.d/apt:
  file.managed:
    - source: salt://apt/update_apt.cron

apt-transport-https:
  pkg.installed

python-apt:
  pkg.installed


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


# APT preferences
/etc/apt/preferences.d/ffho:
  file.managed:
    - source: salt://apt/ffho.preferences


/etc/apt/apt.conf.d/ffho:
  file.managed:
    - source: salt://apt/ffho.apt.conf

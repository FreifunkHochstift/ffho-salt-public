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

ffpb-repo:
  file.absent:
    - name: /etc/apt/sources.list.d/freifunk.list

ffho-repo-jessie:
  pkgrepo.managed:
    - comments:
      - "# FFHO APT repo"
    - human_name: FFHO repository
    - name: deb http://apt.ffho.net/ {{ grains.oscodename }} main contrib non-free
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

{% if grains.oscodename in [ "jessie" ] %}
apt-neoraider:
  pkgrepo.managed:
    - comments:
      - "# Neoraiders APT repo"
    - human_name: Neoraiders APT repo
    - name: deb https://repo.universe-factory.net/debian/ sid main
    - dist: sid
    - file: /etc/apt/sources.list.d/universe-factory.list
    - keyserver: pgpkeys.mit.edu
    - keyid: 16EF3F64CB201D9C
{% else %}
/etc/apt/sources.list.d/universe-factory.list:
  file.absent
{% endif %}

apt-icinga2:
  pkgrepo.managed:
    - comments:
      - "# Icinga2 repo"
    - human_name: Icinga2 repo
    - name: deb http://packages.icinga.org/debian icinga-{{ grains.oscodename }} main
    - file: /etc/apt/sources.list.d/icinga2.list
    - key_url: http://packages.icinga.org/icinga.key


# APT preferences - Pin neoraiders packages to prio 900
/etc/apt/preferences.d/ffho:
  file.managed:
    - source: salt://apt/ffho.preferences


/etc/apt/apt.conf.d/ffho:
  file.managed:
    - source: salt://apt/ffho.apt.conf

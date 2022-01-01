#
# APT
#

/etc/apt/sources.list:
  file.managed:
    - source: salt://apt/sources.list.{{ grains.os }}.{{ grains.oscodename }}

/etc/cron.d/apt:
  file.managed:
    - source: salt://apt/update_apt.cron

# FFHO APT
/etc/apt/trusted.gpg.d/ffho.gpg:
  file.managed:
    - source: salt://apt/ffho.gpg.{{ grains.os }}.{{ grains.oscodename }}

/etc/apt/sources.list.d/ffho.list:
  file.managed:
    - source: salt://apt/ffho.list.{{ grains.os }}.{{ grains.oscodename }}
    - require:
      - file: /etc/apt/trusted.gpg.d/ffho.gpg

# Salt APT
/usr/share/keyrings/salt-archive-keyring.gpg:
  file.managed:
    - source: salt://apt/salt.gpg

/etc/apt/trusted.gpg.d/salt.gpg:
  file.absent

/etc/apt/sources.list.d/salt.list:
  file.managed:
    - source: salt://apt/salt.list.{{ grains.os }}.{{ grains.oscodename }}
    - require:
      - file: /usr/share/keyrings/salt-archive-keyring.gpg

# APT preferences
/etc/apt/preferences.d/ffho:
  file.managed:
    - source: salt://apt/ffho.preferences


/etc/apt/apt.conf.d/ffho:
  file.managed:
    - source: salt://apt/ffho.apt.conf

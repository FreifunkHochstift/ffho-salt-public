#
# APT
#

# OS sources.list
/etc/apt/sources.list:
  file.managed:
    - source: salt://apt/sources.list.{{ grains.os }}.{{ grains.oscodename }}

/etc/cron.d/apt:
  file.managed:
    - source: salt://apt/update_apt.cron

# APT preferences
/etc/apt/preferences.d/ffho:
  file.managed:
    - source: salt://apt/ffho.preferences


/etc/apt/apt.conf.d/ffho:
  file.managed:
    - source: salt://apt/ffho.apt.conf

# New place for keyrings
/etc/apt/keyrings:
  file.directory

# FFHO APT
/etc/apt/trusted.gpg.d/ffho.gpg:
  file.managed:
    - source: salt://apt/ffho.gpg.{{ grains.os }}.{{ grains.oscodename }}

/etc/apt/sources.list.d/ffho.list:
  file.managed:
    - source: salt://apt/ffho.list.{{ grains.os }}.{{ grains.oscodename }}
    - require:
      - file: /etc/apt/trusted.gpg.d/ffho.gpg

# Salt repo
/etc/apt/keyrings/salt-archive-keyring.pgp:
  file.managed:
    - source: salt://apt/salt-archive-keyring.pgp
    - require:
      - file: /etc/apt/keyrings

/etc/apt/sources.list.d/salt.sources:
  file.managed:
    - source: salt://apt/salt.sources
    - require:
      - file: /etc/apt/keyrings/salt-archive-keyring.pgp

/etc/apt/preferences.d/salt-pin-1001:
  file.managed:
    - contents: |
                Package: salt-*
                Pin: version 3006.10*
                Pin-Priority: 1001
    - require:
      - file: /etc/apt/sources.list.d/salt.sources

/etc/apt/sources.list.d/salt.list:
  file.absent

/usr/share/keyrings/salt-archive-keyring.gpg:
  file.absent



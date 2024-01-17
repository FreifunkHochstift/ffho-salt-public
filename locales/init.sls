#
# Configure locales
#

locales:
  pkg.installed

# Workaround missing locale.present in our salt version
/etc/locale.gen:
  file.managed:
    - source:
      - salt://locales/locale.gen.{{ grains.os }}.{{ grains.oscodename }}
      - salt://locales/locale.gen
    - require:
      - pkg: locales

locale-gen:
  cmd.wait:
    - watch:
      - file: /etc/locale.gen

en_US.UTF-8:
  locale.system:
    - require:
      - file: /etc/locale.gen



#
# APU2 - Firmware-Update
#

apu2-flashrom:
  pkg.latest:
    - name: flashrom

{% if salt['pkg.version_cmp'](salt['pkg.version']('flashrom'), '0.9.9') >= 0 %}
apu2-read-firmware:
  cmd.run:
    - name: flashrom --programmer internal --read /tmp/apu2-firmware.rom
    - creates: /tmp/apu2-firmware.rom
    - require:
      - pkg: apu2-flashrom

apu2-copy-firmware:
  file.managed:
    - name: /tmp/apu2-firmware.rom
    - source: salt://apu2/apu2-firmware.rom
    - require:
      - cmd: apu2-read-firmware

apu2-write-firmware:
  cmd.wait:
    - name: flashrom --programmer internal --write /tmp/apu2-firmware.rom
    - watch:
      - file: apu2-copy-firmware
{% endif %}

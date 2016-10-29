#
# Hardware machines
#

{% if grains['manufacturer'] == 'HP' %}
include:
  - hardware.hp
{% endif %}


# Only read PVs from sw/hw RAID and physical disks. Ignore anything else (like PVs within VM LVs).
/etc/lvm/lvm.conf:
  file.managed:
    - source: salt://hardware/lvm.conf

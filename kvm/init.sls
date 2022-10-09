#
# KVM host
#

virt-pkgs:
  pkg.installed:
    - pkgs:
{% if grains.oscodename == 'buster' %}
      - qemu-kvm
      - libvirt-bin
{% elif grains.oscodename == 'bullseye' %}
      - qemu-system-x86
      - libvirt-daemon-system
{% endif %}
      - xmlstarlet
      - netcat-openbsd

/etc/libvirt/hooks/qemu:
  file.managed:
    - source: salt://kvm/qemu-hook
    - mode: 755
    - require:
      - pkg: virt-pkgs

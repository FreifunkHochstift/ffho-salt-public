#
# KVM host
#

virt-pkgs:
  pkg.installed:
    - pkgs:
      - qemu-kvm
      - libvirt-daemon-system
      - libvirt-clients
      - xmlstarlet
      - netcat-openbsd
      - ipmitool
      - lm-sensors

/etc/libvirt/hooks/qemu:
  file.managed:
    - source: salt://kvm/qemu-hook
    - mode: 755
    - require:
      - pkg: virt-pkgs

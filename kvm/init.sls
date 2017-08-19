#
# KVM host
#

virt-pkgs:
  pkg.installed:
    - pkgs:
      - qemu-kvm
      - libvirt-bin
      - xmlstarlet
      - netcat-openbsd

/etc/libvirt/hooks/qemu:
  file.managed:
    - source: salt://kvm/qemu-hook
    - mode: 755
    - require:
      - pkg: virt-pkgs

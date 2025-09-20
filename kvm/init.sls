#
# KVM host
#

virt-pkgs:
  pkg.installed:
    - pkgs:
      - qemu-system-x86
      - libvirt-daemon-system
      - xmlstarlet
      - netcat-openbsd

libvirtd:
  service.running:
    - enable: True
    - reload: True

/etc/libvirt/hooks/qemu:
  file.managed:
    - source: salt://kvm/qemu-hook
    - mode: 755
    - require:
      - pkg: virt-pkgs
    - watch_in:
      - service: libvirtd

/etc/libvirt/hooks/get-bridge-vids:
  file.managed:
    - source: salt://kvm/get-bridge-vids
    - mode: 755
    - require:
      - pkg: virt-pkgs

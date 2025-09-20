#
# Linux Kernel
#

linux-kernel:
  pkg.latest:
    - name: linux-image-{{ grains.osarch }}

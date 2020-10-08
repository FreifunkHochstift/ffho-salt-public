#
# knot-recursor
#

/etc/apt/sources.list.d/knot-resolver.list:
  file.absent

knot-resolver:
  pkg.removed

/etc/systemd/system/kresd@1.service.d:
  file.absent

/etc/systemd/system/kresd.socket.d:
  file.absent

/etc/knot-resolver:
  file.absent

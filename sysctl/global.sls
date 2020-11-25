#
# Sysctl's for all FFMuc machines
#

#
# After kernel oops wait 1 sec, than reset system
kernel.panic_on_oops:
  sysctl.present:
    - value: 1
    - config: /etc/sysctl.d/10-global.conf

kernel.panic:
  sysctl.present:
    - value: 1
    - config: /etc/sysctl.d/10-global.conf

#
# If non-zero, the message will be sent with the primary address of
# the interface that received the packet that caused the icmp error.
# This is the behaviour network many administrators will expect from
# a router. And it can make debugging complicated network layouts
# much easier.
#
# Note that if no primary address exists for the interface selected,
# then the primary address of the first non-loopback interface that
# has one will be used regardless of this setting.
net.ipv4.icmp_errors_use_inbound_ifaddr:
  sysctl.present:
    - value: 1
    - config: /etc/sysctl.d/10-global.conf

#
# Enables child sockets to inherit the L3 master device index.
# Enabling this option allows a "global" listen socket to work
# across L3 master domains (e.g., VRFs) with connected sockets
# derived from the listen socket to be bound to the L3 domain in
# which the packets originated. Only valid when the kernel was
# compiled with CONFIG_NET_L3_MASTER_DEV.
net.ipv4.tcp_l3mdev_accept:
  sysctl.present:
    - value: 1
    - config: /etc/sysctl.d/10-global.conf

#
# Increase ARP garbage collector thresholds
net.ipv4.neigh.default.gc_thresh1:
  sysctl.present:
    - value: 1024
    - config: /etc/sysctl.d/10-global.conf
net.ipv4.neigh.default.gc_thresh2:
  sysctl.present:
    - value: 2048
    - config: /etc/sysctl.d/10-global.conf
net.ipv4.neigh.default.gc_thresh3:
  sysctl.present:
    - value: 8192
    - config: /etc/sysctl.d/10-global.conf

net.ipv6.neigh.default.gc_thresh1:
  sysctl.present:
    - value: 1024
    - config: /etc/sysctl.d/10-global.conf
net.ipv6.neigh.default.gc_thresh2:
  sysctl.present:
    - value: 2048
    - config: /etc/sysctl.d/10-global.conf
net.ipv6.neigh.default.gc_thresh3:
  sysctl.present:
    - value: 8192
    - config: /etc/sysctl.d/10-global.conf

net.ipv6.route.max_size:
  sysctl.present:
    - value: 2147483647
    - config: /etc/sysctl.d/10-global.conf

#
# Increase conntrack table size (default 32k)
net.netfilter.nf_conntrack_max:
  sysctl.present:
    - value: 16777216
    - config: /etc/sysctl.d/10-global.conf

# Disable RA
net.ipv6.conf.default.accept_ra:
  sysctl.present:
    - value: 0
    - config: /etc/sysctl.d/10-global.conf
net.ipv6.conf.all.accept_ra:
  sysctl.present:
    - value: 0
    - config: /etc/sysctl.d/10-global.conf
net.ipv6.conf.default.autoconf:
  sysctl.present:
    - value: 0
    - config: /etc/sysctl.d/10-global.conf
net.ipv6.conf.all.autoconf:
  sysctl.present:
    - value: 0
    - config: /etc/sysctl.d/10-global.conf

#
# Prevent swapping
vm.swappiness:
  sysctl.present:
    - value: 1
    - config: /etc/sysctl.d/10-global.conf

net.ipv4.tcp_congestion_control:
  sysctl.present:
    - value: bbr
    - config: /etc/sysctl.d/10-bbr-congestion.conf

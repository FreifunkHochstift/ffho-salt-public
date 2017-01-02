cr03.in.ffho.net:
  sysLocation: BER

  roles:
    - router
    - routereflector
    - ffrl-exit

  ifaces:
    lo:
      prefixes:
        - 10.132.255.3/32
        - 2a03:2260:2342:ffff::3/128

    eth0:
      prefixes:
        - 185.46.137.162/25
        - 2a00:13c8:1000:2::162/64
      gateway:
        - 185.46.137.129
        - 2a00:13c8:1000:2::1
      vrf: vrf_external

    vlan1015:
      desc: "L2-BER"
      prefixes:
        - <POP L2-Subnet-IP v4>/28
        - <POP L2-Subnet-IP v6>/64

    # DUS
    gre_ffrl_dus_a:
      type: GRE_FFRL
      endpoint: 185.66.193.0
      tunnel-physdev: eth0
      prefixes:
        - <local tunnel IP v4>/31
        - <local tunnel IP v6>/64

#    gre_ffrl_dus_b:
#      [...]
#
#    # FRA
#    gre_ffrl_fra_a:
#
#    gre_ffrl_fra_b:
#
#    # BER
#    gre_ffrl_ber_a:
#
#    gre_ffrl_ber_b:
#

    # NAT IP
    nat:
      link-type: dummy
      prefixes:
        - 185.66.x.y/32

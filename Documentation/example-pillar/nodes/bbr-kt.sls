bbr-kt.in.ffho.net:
  sysLocation: KT

  roles:
    - batman
    - router
    - ffrl-exit

  sites:
    - legacy
    - pad-cty

  ifaces:
    lo:
      prefixes:
        - 10.132.255.197/32
        - 2a03:2260:2342:ffff::197/128

    bond0:
      bond-slaves: "eth0 eth1"
      mtu: 1600

    vlan2200:
      desc: "<-> bbr-voba"
      vlan-raw-device: bond0
      prefixes:
        - <Transfer IP v4>/31
        - <Transfer IP v6>/126
      batman_connect_sites: legacy

    vlan2201:
      desc: "<-> bbr-upb"
      vlan-raw-device: bond0
      prefixes:
        - <Transfer IP v4>/31
        - <Transfer IP v6>/126
      batman_connect_sites: legacy

    vlan2205:
      desc: "<-> bbr-dl0ps"
      vlan-raw-device: bond0
      prefixes:
        - <Transfer IP v4>/31
        - <Transfer IP v6>/126

    vlan3007:
      desc: "Mgmt KT"
      vlan-raw-device: bond0
      prefixes:
        - <Mgmt network prefix>/24
      mtu: 1500

    vlan4006:
      desc: "T-DSL"
      vlan-raw-device: bond0
      vrf: vrf_external
      mtu: 1500


#    # DUS
#    gre_ffrl_dus_a:
#      type: GRE_FFRL
#      endpoint: 185.66.193.0
#      local: <$DSL IP>
#      tunnel-physdev: ppp0
#      prefixes:
#        - <Transfer Prefix v4>/31
#        - <Transfer Prefix v6>/126
#
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

    # NAT IP
    nat:
      link-type: dummy
      prefixes:
        - 185.66.x.y/32

  alfred:
    location_lat: '51.726572935605475'
    location_lon: '8.798632621765135'

{% if grains['id'] == 'bbr-kt.in.ffho.net' %}
  pppoe:
    user: "<081547112342>#0001@$ISP.de"
    pass: "<1234567890>"
{% endif %}

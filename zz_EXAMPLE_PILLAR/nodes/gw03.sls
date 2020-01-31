gw03.in.ffho.net:
  id: 11

  sysLocation: BER

  roles:
    - router
    - batman
    - batman_gw
    - batman_ext
    - fastd

  sites:
    - legacy
    - pad-cty
    - hx-nord

  ifaces:
    lo:
      prefixes:
        - 10.132.255.11/32
        - 2a03:2260:2342:ffff::11/128

    eth0:
      desc: SysEleven
      mac: 52:54:1f:03:01:63
      #
      prefixes:
        - 185.46.137.163/25
        - 2a00:13c8:1000:2::163/64
      gateway:
        - 185.46.137.129
        - 2a00:13c8:1000:2::1
      vrf: vrf_external

    vlan1015:
      desc: L2-BER
      mac: 52:54:1f:03:10:15
      prefixes:
        - <POP L2-Subnet prefix v4>/28
        - <POP L2-Subnet prefix v6>/64

    he-ipv6:
      method: tunnel
      desc: HE IPv6 Transit
      mode: sit
      ttl: 255
      local: 185.46.137.163
      endpoint: <HE endpoint>
      tunnel-physdev: vrf_external
      prefixes:
        - <v6 transfer network>/64

    br-legacy:
      desc: "Site Legacy"
      bridge-ports: bat-legacy
      prefixes:
        - 2001:470:6d:860:8::3/64

    br-pad-cty:
      desc: "Site Paderborn City"
      bridge-ports: bat-pad-cty
      prefixes:
        - 10.132.32.3/20
        - 2a03:2260:2342:100::3/64

    br-hx-nord:
      desc: "Site Hoexter Nord"
      bridge-ports: bat-hx-nord
      prefixes:
        - 10.132.96.3/21
        - 2a03:2260:2342:800::3/64


  fastd:
    nodes_pubkey: <public key here>
    intergw_pubkey: <public key here>

{% if grains['id'] == 'gw03.in.ffho.net' %}
    nodes_privkey: <private key here>
    intergw_privkey: <private key here>
{% endif %}

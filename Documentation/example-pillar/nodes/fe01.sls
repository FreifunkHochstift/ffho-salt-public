fe01.in.ffho.net:
  sysLocation: Vega

  roles:
    - router
    - frontend

  ifaces:
    lo:
      prefixes:
        - 10.132.255.29/32
        - 2a03:2260:2342:ffff::29/128

    vlan1013:
      desc: "L2-Vega"
      prefixes:
        - <POP L2-Subnet prefix v4>/28
        - <POP L2-Subnet prefix v6>/64

    eth0:
      desc: "Ext. Vega"
      prefixes:
        - 80.70.181.61/32
        - 2a02:450:1:6::10/64
      pointopoint: 80.70.181.56
      gateway:
        - 80.70.181.56
        - 2a02:450:1:6::1
      vrf: vrf_external

    veth_int2ext:
      prefixes:
        - <vEth transfer prefix v4>/31
        - <vEth transfer prefix v6>/126

    veth_ext2int:
      prefixes:
        - <vEth transfer prefix v4>/31
        - <vEth transfer prefix v6>/126
      vrf: vrf_external


  nginx:
    websites:
      - ff-frontend.conf
      - node.ffho.net

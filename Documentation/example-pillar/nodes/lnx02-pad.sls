lnx02.pad.in.ffho.net:
  sysLocation: Vega

  roles:
    - router
    - kvm

  ifaces:
    lo:
      prefixes:
        - 10.132.255.12/32
        - 2a03:2260:2342:ffff::12/128

    bond0:
      bond-slaves: "eth1"
      bridge-vids: "100 101 200 201 1013 2000 2004 2006 3002 4002"

    br0:
      bridge-ports: bond0
      bridge-vlan-aware: yes
      bridge-ports-condone-regex: "^[a-zA-Z0-9]+_(eth[0-9]+|v[0-9]{1,4})$"
      bridge-vids: "100 101 200 201 1013 2000 2004 2006 3002 4002"

    br0.1013:
      desc: "L2-Vega"
      prefixes:
        - <POP L2-Subnet prefix v4>/28
        - <POP L2-Subnet prefix v6>/64
      ospf:
        mode: active

    br0.4002:
      vlan-raw-device: br0
      prefixes:
        - 80.70.180.52/29
        - 2a02:450:0:6::52/64
      gateway:
        - 80.70.180.49
        - 2a02:450:0:6::1
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

    br-vm:
      bridge-ports: none
      bridge-ports-condone-regex: "^[a-zA-Z0-9]+_(v[0-9]{1,4}|)eth[0-9])$"
      prefixes:
        - <VM Gateway prefixes>
      vrf: vrf_external

    fe01_eth0:
      auto: False
      post-up:
        - "ip    route add 80.70.181.61/32 dev br-vm table vrf_external"
        - "ip -6 route add 2a02:450:1:6::10/128 dev br-vm table vrf_external"

    mail_eth0:
      auto: False
      post-up:
        - "ip    route add 80.70.181.59/32 dev br-vm table vrf_external"
        - "ip -6 route add 2a02:450:1::10/128 dev br-vm table vrf_external"

    cr02_eth0:
      desc: "cr02 external"
      auto: False
      post-up:
        - "ip    route add 80.70.181.62/32 dev br-vm table vrf_external"
        - "ip -6 route add 2a02:450:1:5::10/128 dev br-vm table vrf_external"

    cr02_eth1:
      desc: "cr02 internal trunk"
      bridge-vids: "1013 2000 2004 2006 3002"

  ssh:
    root:
{% if grains['id'] == 'lnx02.pad.in.ffho.net' %}
      privkey: |
        -----BEGIN RSA PRIVATE KEY-----
        ...
        -----END RSA PRIVATE KEY-----
{% endif %}
      pubkey: ssh-rsa ABCD... root@lnx02.pad.in.ffho.net

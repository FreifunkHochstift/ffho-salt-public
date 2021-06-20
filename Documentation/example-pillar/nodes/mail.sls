mail.in.ffho.net:
  id: 30

  loopback_override:
    v4: 80.70.181.59
    v6: 2a02:450:1::25

  sysLocation: Vega

  mailname: mail.ffho.net

  roles:
    - mx

  ifaces:
    eth0:
      desc: "Upstream Vega"
      prefixes:
        - 80.70.181.59/32
        - 2a02:450:1::25/64
      pointopoint: 80.70.181.56
      gateway:
        - 80.70.181.56
        - 2a02:450:1::1

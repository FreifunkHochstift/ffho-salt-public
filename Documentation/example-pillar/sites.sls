sites:
  # Legacy
  legacy:
    site_no: 0
    name: paderborn.freifunk.net
    prefix_v4: 10.132.0.0/19
    prefix_v6: fdca:ffee:ff12:132::/64


  # Paderborn (Kernstadt)
  pad-cty:
    site_no: 1
    name: Paderborn (Kernstadt)
    prefix_v4: 10.132.32.0/20
    prefix_v6: 2a03:2260:2342:100::/64
    next_node_v4: 10.132.32.1
    next_node_v6: 2a03:226:2342:100::1
    domain_seed: <domain seed here>

  # Paderborn (Umland)
  pad-uml:
    site_no: 2
    name: Paderborn (Umland)
    prefix_v4: 10.132.48.0/21
    prefix_v6: 2a03:2260:2342:200::/64
    next_node_v4: 10.132.48.1
    next_node_v6: 2a03:226:2342:200::1
    domain_seed: <domain seed here>

  # Bueren
  buq:
    site_no: 3
    name: Bueren
    prefix_v4: 10.132.56.0/21
    prefix_v6: 2a03:2260:2342:300::/64
    next_node_v4: 10.132.56.1
    next_node_v6: 2a03:226:2342:300::1
    domain_seed: <domain seed here>


  # Kreis Paderborn
  pb-nord:
    site_no: 4
    name: PB-Nord
    prefix_v4: 10.132.64.0/21
    prefix_v6: 2a03:2260:2342:400::/64
    next_node_v4: 10.132.64.1
    next_node_v6: 2a03:226:2342:400::1
    domain_seed: <domain seed here>

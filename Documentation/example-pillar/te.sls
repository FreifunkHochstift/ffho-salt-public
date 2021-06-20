te:

# Which communities should be evaluated at which nodes for which routing
# decisions?
  community_map:

#  EXAMPLE
#
#  node01.in.ffho.net:
#    <logical entity, e.g. "ffrl">:
#      - COMMUNITY_ONE
#
#  Up to now the only predefined entity is "ffrl" which controls which
#  routes tagged with "EXPORT_RESTRICT" will be exported to AS20101 at
#  the given node.
    
    cr03.in.ffho.net:
      ffrl:
        - EXPORT_ONLY_AT_CR03


# Tag prefixes with communities at given nodes
  prefixes:

#  EXAMPLE
#
#   <prefix/mask>:
#     desc: "my magic prefix"
#     communities:
#       - COMMUNITY_ONE
#       - "(12345, 4711)"
#     nodes:
#       - node01.in.ffho.net

    2a03:2260:2342::/52:
      desc: "Mesh Prefixes"
      communities:
        - EXPORT_RESTRICT
        - EXPORT_ONLY_AT_CR03
      nodes:
        - cr03.in.ffho.net

    10.132.32.0/23:
      desc: "Gw03 Pad-Cty prefix"
      communities:
        - GATEWAY_TE_ROUTE
      nodes:
        - gw03.in.ffho.net

    10.132.96.0/23:
      desc: "Gw03 PB-Nord prefix"
      communities:
        - GATEWAY_TE_ROUTE
      nodes:
        - gw03.in.ffho.net

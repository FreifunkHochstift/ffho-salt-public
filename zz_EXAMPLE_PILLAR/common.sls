mine_functions:
  minion_id:
    - mine_function: grains.get
    - id
    - mine_interval: 60
  minion_address:
    - mine_function: pillar.get
    - netbox:primary_ip4:address
    - mine_interval: 60
  minion_address6:
    - mine_function: pillar.get
    - netbox:primary_ip6:address
    - mine_interval: 60

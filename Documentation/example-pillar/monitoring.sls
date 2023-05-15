monitoring:
  #
  # Used by netfilter module to generate nftables rules to allow monitoring access
  #

  librenms:
    role: librenms
    nftables_rule_spec: "udp dport 161"

  # A simple exporter which runs everywhere
  prometheus-node-exporter:
    role: prometheus-server
    nftables_rule_spec: "tcp dport 9100"

  prometheus-bind-exporter:
    # role of the node(s) running the server querying other nodes
    role: prometheus-server
    # list of roles where this exporter will be running and needs to be allowed
    node_roles:
      - dns-auth
      - dns-recursor
    nftables_rule_spec: "tcp dport 9119"

  prometheus-bird-exporter:
    role: prometheus-server
    node_roles:
      - router
    nftables_rule_spec: "tcp dport 9324"

  icinga2:
    role: icinga2server


{% if grains['id'] in ["<id>"] %}
  users:
    ffho-ops:
      display_name: "<name>"
      telegram_chat_id: "-<group id>"

    # ...

  private:
    telegram_bot_token: "<token>"
{% endif %}

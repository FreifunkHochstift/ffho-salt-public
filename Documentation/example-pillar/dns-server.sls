#
# DNS related settings
#

dns-server:

  # Reference NS for sync checks
  reference_ns: <IP of primary auth NS>


# These settings are only relevant for boxes running DNS and monitoring
{% if grains['id'].startswith ('dns') or grains['id'].startswith ('infra-') or grains['id'].startswith ('icinga2') %}

  acls:
    ffho-ops:
      entries:
        - <OPS prefixes>

    slaves:
      entries:
        - <IPv4 / IPv6 IPs of DNS slaves>

  # Defaults if not specified below
  zone_defaults:
    type: master
    # ACLs defined above
    allow-transfer: "slaves; localhost; ffho-ops;"

  zones:
    # public zones
    paderborn.freifunk.net:
      file: /etc/bind/zones/static/paderborn.freifunk.net.zone

    hochstift.freifunk.net:
      file: /etc/bind/zones/static/hochstift.freifunk.net.zone

    ffho.net:
      file: /etc/bind/zones/generated/ffho.net.zone

    # reverse zones etc.
    # ...


  # Configuration for authoritive name server
  auth:

    ips:
      - <IPv4 / IPv6 IP of priamry auth NS>

    allow-recursion:
      - <Networks to allow recursive queries from>

{% endif %}

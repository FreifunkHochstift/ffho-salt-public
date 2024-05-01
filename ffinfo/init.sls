#
# Basic system related information
#

/etc/freifunk:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

# Generate /etc/freifunk/role file with main role the node has configured in NetBox
/etc/freifunk/role:
  file.managed:
    - contents: {{ salt['pillar.get']('node:role', "") }}

# Generate /etc/freifunk/roles file with all roles configured on the node,
# one on each line.
/etc/freifunk/roles:
  file.managed:
    - source: salt://ffinfo/list.tmpl
    - template: jinja
      list: {{ salt['pillar.get']('node:roles', []) }}

# Generate /etc/freifunk/sites file with all sites configured on the node,
# one on each line. Empty if no sites configured.
/etc/freifunk/sites:
  file.managed:
    - source: salt://ffinfo/list.tmpl
    - template: jinja
      list: {{ salt['pillar.get']('node:sites', []) }}

# Generate /etc/freifunk/status file with the status of this node
{% set status = salt['pillar.get']('node:status', 'UNKNOWN') %}
/etc/freifunk/status:
  file.managed:
    - contents: {{ status }}

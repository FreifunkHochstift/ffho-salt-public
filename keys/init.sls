

#
# SSH private key for GIT access
{% if 'fastd_peers' in salt['pillar.get'] ('nodes:' ~ grains['id'] ~ ':roles', []) %}
/root/.ssh/ffho_peers_git.id_rsa:
  file.managed:
    - contents_pillar: ffho:keys:peers_git:ssh_privkey
    - user: root
    - group: root
    - mode: 400
{% endif %}

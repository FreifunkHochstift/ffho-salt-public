#
# Bash
#

#
# .bashrc for root
/root/.bashrc:
  file.managed:
    - source: salt://bash/bashrc.root
    - template: jinja

#
# Nifty aliases for gateway
{% if 'batman_gw' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
/root/.bash_aliases:
  file.managed:
    - source: salt://bash/bash_aliases.root
{% endif %}


# bashrc.user is used in state 'build' for the build user!

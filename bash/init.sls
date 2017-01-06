#
# Bash
#

{%- import "globals.sls" as globals with context %}

#
# .bashrc for root
/root/.bashrc:
  file.managed:
    - source: salt://bash/bashrc.root
    - template: jinja

#
# Nifty aliases for gateway
{% if 'gateway' in globals.ROLES %}
/root/.bash_aliases:
  file.managed:
    - source: salt://bash/bash_aliases.root
{% endif %}


# bashrc.user is used in state 'build' for the build user!

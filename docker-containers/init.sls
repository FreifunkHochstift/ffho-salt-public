#
# Docker containers
#

{% if 'docker01' in grains['id'] %}
/srv/docker/p:
  file.managed:
    - source: salt://sysctl/router.conf
    - watch_in:
      - cmd: reload-sysctl
{% elif 'guardian.in.ffmuc.net' in grains['id'] %}

{% endif %}


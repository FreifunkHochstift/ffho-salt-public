#
# Linux Kernel
#

linux-4.7:
  pkg.installed:
    - name: linux-image-4.7.0-0.bpo.1-amd64
    - fromrepo: jessie-backports

{#
 # Install kernel headers if we might need to compile a batman_adv module on this node.
 #}
{% if 'batman' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
linux-4.7-headers:
  pkg.installed:
    - name: linux-headers-4.7.0-0.bpo.1-amd64
    - fromrepo: jessie-backports
{% endif %}

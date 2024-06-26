#
# Install and configure configured network suite, configure links and install
# /etc/network/interfaces but do not reload the interafces.
#
# To be called from pressed
#

# Which networ suite to configure?
{% set default_suite = salt['pillar.get']('network:suite', 'ifupdown2') %}
{% set suite = salt['pillar.get']('node:network:suite', default_suite) %}

include:
 - network.link
 - network.interfaces
 - network.{{ suite }}

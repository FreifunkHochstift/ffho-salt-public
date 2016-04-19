#
# Install and configure console-tools to disable scree blanking
#

{% if grains['oscodename'] == 'wheezy' %}
console-tools:
  pkg.installed:
    - name: console-tools

/etc/console-tools/config:
  file.managed:
    - source: salt://console-tools/config
    - require:
      - pkg: console-tools
{%- endif %}

{% if grains['oscodename'] == 'jessie' %}
/etc/issue:
  file.managed:
    - source: salt://console-tools/issue.Debian.jessie
{% endif %}

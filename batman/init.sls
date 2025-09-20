#
# Set up B.A.T.M.A.N. module 'n stuff
#

#
# Only set up batman and load batman_adv kernel module if the role »batman«
# has been configured for this node.
#
{%- set roles = salt['pillar.get']('node:roles', []) %}

{%- if 'batman' in roles %}
batctl:
  pkg.latest:
    - name: batctl


# Convenience bat-hosts file for informative batctl output
/etc/bat-hosts:
  file.managed:
    - source: salt://batman/bat-hosts.tmpl
    - template: jinja


# Make sure the batman_adv module is loaded at boot time
/etc/modules-load.d/batman-adv.conf:
  file.managed:
      - source: salt://batman/batman-adv.module.conf


#
# Is this node a B.A.T.M.A.N. gateway?
  {%- if 'batman_gw' in roles %}

/etc/cron.d/ff_check_gateway:
  file.managed:
    - source: salt://batman/ff_check_gateway.cron
    - template: jinja

/usr/local/sbin/ff_check_gateway:
  file.managed:
    - source: salt://batman/ff_check_gateway
    - mode: 755
    - user: root
    - group: root

  {% endif %}

#
# If the role »batman» is NOT configured for this node, make sure to purge any
# traces of a previous installation, if present.
#
{% else %}

batctl:
  pkg.purged

batman-adv-dkms:
  pkg.purged

/etc/bat-hosts:
  file.absent

/etc/modules-load.d/batman-adv.conf:
  file.absent

/etc/cron.d/ff_check_gateway:
  file.absent

/usr/local/sbin/ff_check_gateway:
  file.absent
{% endif %}

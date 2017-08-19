#
# Set up B.A.T.M.A.N. module 'n stuff
#

#
# Only set up batman and load batman_adv kernel module if the role »batman«
# has been configured for this node.
#
{%- set roles = salt['pillar.get']('nodes:' ~ grains['id']  ~ ':roles', []) %}
include:
  - apt

{%- if 'batman' in roles %}
batctl:
  pkg.installed


# Convenience bat-hosts file for informative batctl output
/etc/bat-hosts:
  file.managed:
    - source: salt://batman/bat-hosts.tmpl
    - template: jinja


  {% if salt['ffho.re_search'] ('-v14', grains['id']) %}
batman-adv-dkms:
  pkg.installed:
    - require:
      - pkgrepo: apt-neoraider

# The ff_fix_batman script ensures that the preferred (currently older) version
# of the batman_adv kernel module is compiled via DKMS and installed into the
# system.
/usr/local/sbin/ff_fix_batman:
  file.managed:
    - source: salt://batman/ff_fix_batman
    - user: root
    - group: root
    - mode: 744
    - require:
      - pkg: batctl

ff_fix_batman:
  cmd.wait:
    - name: /usr/local/sbin/ff_fix_batman
    - require:
      - file: /usr/local/sbin/ff_fix_batman
    - watch:
      - pkg: batman-adv-dkms


# Install and enable a ff-fix-batman service which runs at boot time
# to fix the kernel module after a kernel upgrade + reboot if neccessary.
/lib/systemd/system/ff-fix-batman.service:
  file.managed:
    - source: salt://batman/ff_fix_batman.service
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: /usr/local/sbin/ff_fix_batman

enable-ff-fix-batman-service:
  service.enabled:
    - name: ff-fix-batman
    - require:
      - file: /lib/systemd/system/ff-fix-batman.service

  {% endif %}

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

/usr/local/sbin/ff_fix_batman:
  file.absent

disable-ff-fix-batman-service:
  service.disabled:
    - name: ff-fix-batman

/lib/systemd/system/ff-fix-batman.service:
  file.absent

/etc/modules-load.d/batman-adv.conf:
  file.absent

/etc/bat-hosts:
  file.absent

/etc/cron.d/ff_check_gateway:
  file.absent

/usr/local/sbin/ff_check_gateway:
  file.absent
{% endif %}

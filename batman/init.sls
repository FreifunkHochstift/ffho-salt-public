#
# Set up B.A.T.M.A.N. module 'n stuff
#

#
# Only set up batman and load batman_adv kernel module if the role »batman«
# has been configured for this node.
#
{%- if 'batman' in salt['pillar.get']('nodes:' ~ grains['id']  ~ ':roles', ()) %}
include:
  - apt

batman-adv-dkms:
  pkg.installed:
    - require:
      - pkgrepo: apt-neoraider

batctl:
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


# Make sure the batman_adv module is loaded at boot time
/etc/modules-load.d/batman-adv.conf:
  file.managed:
      - source: salt://batman/batman-adv.module.conf


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
{% endif %}

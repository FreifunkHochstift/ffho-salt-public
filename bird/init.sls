#
# Bird routing daemon
#

{%- set roles = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}

include:
  - network.interfaces

bird-repo:
  pkgrepo.managed:
    - comments: "# Official bird repo"
    - human_name: Official bird repository
    - name: "deb http://bird.network.cz/debian/ {{ grains['oscodename'] }} main"
    - dist: {{ grains['oscodename'] }}
    - file: /etc/apt/sources.list.d/bird.list
    - key_url: salt://bird/bird_apt.key


bird-pkg:
  pkg.installed:
    - name: bird
    - require:
      - pkgrepo: bird-repo
      - sls: network.interfaces


# Make sure both services are enabled
bird:
  service.running:
    - enable: True
    - running: True

bird6:
  service.running:
    - enable: True
    - running: True


# Reload commands for bird{,6} to be tied to files which should trigger reconfiguration
bird-configure:
  cmd.wait:
    - name: /usr/sbin/birdc configure
    - watch: []

bird6-configure:
  cmd.wait:
    - name: /usr/sbin/birdc6 configure
    - watch: []


/etc/bird:
  file.directory:
    - mode: 750
    - user: bird
    - group: bird
    - require:
      - pkg: bird


/etc/bird/bird.d:
  file.directory:
    - makedirs: true
    - mode: 755
    - user: root
    - group: bird
    - require:
      - file: /etc/bird

/etc/bird/bird.conf:
  file.managed:
    - source: salt://bird/bird.conf
    - template: jinja
    - require:
      - file: /etc/bird/bird.d
    - require_in:
      - service: bird
    - watch_in:
      - cmd: bird-configure
    - mode: 644
    - user: root
    - group: bird


/etc/bird/bird6.d:
  file.directory:
    - makedirs: true
    - mode: 755
    - user: root
    - group: bird
    - require:
      - file: /etc/bird

/etc/bird/bird6.conf:
  file.managed:
    - source: salt://bird/bird6.conf
    - template: jinja
    - require:
      - file: /etc/bird/bird6.d
    - watch_in:
      - cmd: bird6-configure
    - mode: 644
    - user: root
    - group: bird
    - require_in:
      - service: bird6

#
# External VRF / Routing table?
#
/etc/bird/bird.d/VRF_external.conf:
  file.managed:
    - source: salt://bird/VRF_external.conf
    - template: jinja
      proto: v4
    - watch_in:
      - cmd: bird-configure
    - require:
      - file: /etc/bird/bird.d
    - require_in:
      - service: bird

/etc/bird/bird6.d/VRF_external.conf:
  file.managed:
    - source: salt://bird/VRF_external.conf
    - template: jinja
      proto: v6
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6

/etc/bird/bird.d/external.conf:
  file.absent
/etc/bird/bird6.d/external.conf:
  file.absent


#
# IGP / OSPF
#
/etc/bird/bird.d/IGP.conf:
  file.managed:
    - source: salt://bird/IGP.conf
    - template: jinja
      proto: v4
    - watch_in:
      - cmd: bird-configure
    - require:
      - file: /etc/bird/bird.d
    - require_in:
      - service: bird

/etc/bird/bird6.d/IGP.conf:
  file.managed:
    - source: salt://bird/IGP.conf
    - template: jinja
      proto: v6
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6

# Compatibility glue
/etc/bird/bird6.d/IGP6.conf:
  file.absent:
    - watch_in:
      - cmd: bird-configure


#
# iBGP
#
/etc/bird/ff-policy.conf:
  file.managed:
    - source: salt://bird/ff-policy.conf
    - template: jinja
      proto: v4
    - watch_in:
      - cmd: bird-configure
    - require:
      - file: /etc/bird/bird.d
    - require_in:
      - service: bird

/etc/bird/ff-policy6.conf:
  file.managed:
    - source: salt://bird/ff-policy.conf
    - template: jinja
      proto: v6
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6

/etc/bird/bird.d/ibgp.conf:
  file.managed:
    - source: salt://bird/ibgp.conf
    - template: jinja
      proto: v4
    - watch_in:
      - cmd: bird-configure
    - require:
      - file: /etc/bird/bird.d
    - require_in:
      - service: bird

/etc/bird/bird6.d/ibgp.conf:
  file.managed:
    - source: salt://bird/ibgp.conf
    - template: jinja
      proto: v6
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6



#
# FFRL-exit
#
{% if 'ffrl-exit' in roles %}
/etc/bird/bird.d/ffrl.conf:
  file.managed:
    - source: salt://bird/ffrl.conf
    - template: jinja
      proto: v4
    - watch_in:
      - cmd: bird-configure
    - require:
      - file: /etc/bird/bird.d
    - require_in:
      - service: bird

/etc/bird/bird6.d/ffrl.conf:
  file.managed:
    - source: salt://bird/ffrl.conf
    - template: jinja
      proto: v6
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6


/etc/bird/bird.d/bogon_unreach.conf:
  file.managed:
    - source: salt://bird/bogon_unreach.conf
    - template: jinja
      proto: v4
    - watch_in:
      - cmd: bird-configure
    - require:
      - file: /etc/bird/bird.d
    - require_in:
      - service: bird

/etc/bird/bird6.d/bogon_unreach.conf:
  file.managed:
    - source: salt://bird/bogon_unreach.conf
    - template: jinja
      proto: v6
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6

{% else %}
/etc/bird/bird.d/ffrl.conf:
  file.absent

/etc/bird/bird6.d/ffrl.conf:
  file.absent

/etc/bird/bird.d/bogon_unreach.conf:
  file.absent

/etc/bird/bird6.d/bogon_unreach.conf:
  file.absent
{% endif %}


#
# B.A.T.M.A.N. Gateway
#
{% if 'batman_gw' in roles %}
/etc/bird/bird6.d/radv.conf:
  file.managed:
    - source: salt://bird/radv.conf
    - template: jinja
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6
{% else %}
/etc/bird/bird6.d/ravd.conf:
  file.absent
{% endif %}

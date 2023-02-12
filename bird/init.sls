#
# Bird routing daemon
#

{%- set roles = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
{%- set status = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':status', 'active') %}

include:
  - network.interfaces

bird-pkg:
  pkg.installed:
    - name: bird

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
      proto: v4
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
    - source: salt://bird/bird.conf
    - template: jinja
      proto: v6
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

#
# IGP / OSPF
#
/etc/bird/bird.d/IGP.conf:
  file.managed:
    - source: salt://bird/IGP.conf
    - template: jinja
      AF: 4
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
      AF: 6
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6


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
      family: "4"
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
      family: "6"
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
  file.absent:
    - watch_in:
      - cmd: bird-configure

/etc/bird/bird6.d/ffrl.conf:
  file.absent:
    - watch_in:
      - cmd: bird6-configure

/etc/bird/bird.d/bogon_unreach.conf:
  file.absent:
    - watch_in:
      - cmd: bird-configure

/etc/bird/bird6.d/bogon_unreach.conf:
  file.absent:
    - watch_in:
      - cmd: bird6-configure
{% endif %}


#
# B.A.T.M.A.N. Gateway
#
{% if 'batman_gw' in roles %}
/etc/bird/bird.d/mesh_routes.conf:
  file.managed:
    - source: salt://bird/mesh_routes.conf
    - template: jinja
    - watch_in:
      - cmd: bird-configure
    - require:
      - file: /etc/bird/bird.d
    - require_in:
      - service: bird

/etc/bird/bird6.d/mesh_routes.conf:
  file.managed:
    - source: salt://bird/mesh_routes.conf
    - template: jinja
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6

{% else %}
/etc/bird/bird.d/mesh_routes.conf:
  file.absent:
    - watch_in:
      - cmd: bird-configure
/etc/bird/bird6.d/mesh_routes.conf:
  file.absent:
    - watch_in:
      - cmd: bird6-configure
{% endif %}


#
# L3 Access
#
{% if 'l3-access' in roles %}
/etc/bird/bird.d/l3-access.conf:
  file.managed:
    - source: salt://bird/l3-access.conf
    - template: jinja
    - watch_in:
      - cmd: bird-configure
    - require:
      - file: /etc/bird/bird.d
    - require_in:
      - service: bird

/etc/bird/bird6.d/l3-access.conf:
  file.managed:
    - source: salt://bird/l3-access.conf
    - template: jinja
    - watch_in:
      - cmd: bird6-configure
    - require:
      - file: /etc/bird/bird6.d
    - require_in:
      - service: bird6

{% else %}
/etc/bird/bird.d/l3-access.conf:
  file.absent:
    - watch_in:
      - cmd: bird-configure
/etc/bird/bird6.d/l3-access.conf:
  file.absent:
    - watch_in:
      - cmd: bird6-configure
{% endif %}


#
# RAdvd (for B.A.T.M.A.N. Gateways / L3-Access)
#
{% if status in [ 'active', 'offline' ] and ('radv' in roles or 'l3-access' in roles or ('batman_gw' in roles and grains.id.startswith('gw'))) %}
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
/etc/bird/bird6.d/radv.conf:
  file.absent:
    - watch_in:
      - cmd: bird6-configure
{% endif %}

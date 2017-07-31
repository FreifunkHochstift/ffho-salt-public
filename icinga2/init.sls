#
# Icinga2
#
{% set roles = salt['pillar.get']('nodes:' ~ grains.id ~ ':roles', []) %}

include:
  - apt


# Install icinga2 package
icinga2:
  pkg.installed:
    - name: icinga2
  service.running:
    - enable: True
    - reload: True

# Install plugins (official + our own)
monitoring-plugin-pkgs:
  pkg.installed:
    - pkgs:
      - monitoring-plugins
      - nagios-plugins-contrib
      - libyaml-syck-perl
{% if grains['oscodename'] == 'jessie' %}
      - libnagios-plugin-perl
{% else %}
      - libmonitoring-plugin-perl
{% endif %}
      - lsof
    - watch_in:
      - service: icinga2

ffho-plugins:
  file.recurse:
    - name: /usr/local/share/monitoring-plugins/
    - source: salt://icinga2/plugins/
    - file_mode: 755
    - dir_mode: 755
    - user: root
    - group: root

# Install sudo
sudo:
  pkg.installed

/etc/sudoers.d/icinga2:
  file.managed:
    - source: salt://icinga2/icinga2.sudoers
    - mode: 0440


# Icinga2 master config (for master and all nodes)
/etc/icinga2/icinga2.conf:
  file.managed:
    - source:
      - salt://icinga2/icinga2.conf.H_{{ grains.id }}
      - salt://icinga2/icinga2.conf
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2


# Add FFHOPluginDir
/etc/icinga2/constants.conf:
  file.managed:
    - source: salt://icinga2/constants.conf
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2


# Connect "master" and client zones
/etc/icinga2/zones.conf:
  file.managed:
    - source:
      - salt://icinga2/zones.conf.H_{{ grains.id }}
      - salt://icinga2/zones.conf
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2


# Install host cert + key readable for icinga
{% set pillar_name = 'nodes:' ~ grains['id'] ~ ':certs:' ~ grains['id'] %}
/etc/icinga2/pki/ffhohost.cert.pem:
  file.managed:
    {% if salt['pillar.get'](pillar_name ~ ':cert') == "file" %}
    - source: salt://certs/certs/{{ cn }}.cert.pem
    {% else %}
    - contents_pillar: {{ pillar_name }}:cert
    {% endif %}
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2

/etc/icinga2/pki/ffhohost.key.pem:
  file.managed:
    - contents_pillar: {{ pillar_name }}:privkey
    - user: root
    - group: nagios
    - mode: 440
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2


# Activate Icinga2 features: API
{% for feature in ['api'] %}
/etc/icinga2/features-enabled/{{ feature }}.conf:
  file.symlink:
    - target: "../features-available/{{ feature }}.conf"
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2
{% endfor %}


# Install command definitions
/etc/icinga2/commands.d:
  file.recurse:
    - source: salt://icinga2/commands.d
    - file_mode: 644
    - dir_mode: 755
    - user: root
    - group: root
    - clean: true
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2
   

# Create directory for ffho specific configs
/etc/icinga2/ffho-conf.d:
  file.directory:
    - makedirs: true
    - require:
      - pkg: icinga2


################################################################################
#                               Icinga2 Server                                 #
################################################################################
{% if 'icinga2server' in roles %}

# Install command definitions
/etc/icinga2/ffho-conf.d/services:
  file.recurse:
    - source: salt://icinga2/services
    - file_mode: 644
    - dir_mode: 755
    - user: root
    - group: root
    - clean: true
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2


# Create client node/zone objects
Create /etc/icinga2/ffho-conf.d/hosts/generated/:
  file.directory:
    - name: /etc/icinga2/ffho-conf.d/hosts/generated/
    - makedirs: true
    - require:
      - pkg: icinga2

Cleanup /etc/icinga2/ffho-conf.d/hosts/generated/:
  file.directory:
    - name: /etc/icinga2/ffho-conf.d/hosts/generated/
    - clean: true

  # Generate config file for every client known to pillar
  {% for node_id, node_config in salt['pillar.get']('nodes', {}).items () %}
    {% if node_config.get ('icinga2', "") != 'ignore' %}
/etc/icinga2/ffho-conf.d/hosts/generated/{{ node_id }}.conf:
  file.managed:
    - source: salt://icinga2/host.conf.tmpl
    - template: jinja
    - context:
      node_id: {{ node_id }}
      node_config: {{ node_config }}
    - require:
      - file: Create /etc/icinga2/ffho-conf.d/hosts/generated/
    - require_in:
      - file: Cleanup /etc/icinga2/ffho-conf.d/hosts/generated/
    - watch_in:
      - service: icinga2
    {% endif %}
  {% endfor %}


# Create configuration for network devices
/etc/icinga2/ffho-conf.d/net/wbbl/:
  file.directory:
    - makedirs: true
    - require:
      - pkg: icinga2

  # Generate config files for every WBBL device known to pillar
  {% for link_id, link_config in salt['pillar.get']('net:wbbl', {}).items () %}
/etc/icinga2/ffho-conf.d/net/wbbl/{{ link_id }}.conf:
  file.managed:
    - source: salt://icinga2/wbbl.conf.tmpl
    - template: jinja
    - context:
      link_id: {{ link_id }}
      link_config: {{ link_config }}
    - require:
      - file: /etc/icinga2/ffho-conf.d/net/wbbl/
    - watch_in:
      - service: icinga2
  {% endfor %}


################################################################################
#                               Icinga2 Client                                 #
################################################################################
{% else %}

# Nodes should accept config and commands from Icinga2 server
/etc/icinga2/features-available/api.conf:
  file.managed:
    - source: salt://icinga2/api.conf
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2

/etc/icinga2/check-commands.conf:
  file.absent:
    - watch_in:
      - service: icinga2
{% endif %}




################################################################################
#                              Check related stuff                             #
################################################################################
/etc/icinga2/ffho-conf.d/bird_ospf_interfaces_down_ok.txt:
  file.managed:
    - source: salt://icinga2/bird_ospf_interfaces_down_ok.txt.tmpl
    - template: jinja
    - require:
      - file: /etc/icinga2/ffho-conf.d


#
# Icinga2
#
{% if 'icinga2_server' in salt['pillar.get']('netbox:config_context:roles') or 'icinga2_client' in salt['pillar.get']('netbox:config_context:roles') %}
{% if salt['pillar.get']('netbox:role:name') %}
{%- set role = salt['pillar.get']('netbox:role:name') %}
{% else %}
{%- set role = salt['pillar.get']('netbox:device_role:name') %}
{% endif %}

include:
  - apt
  - sudo


# Install icinga2 package
icinga2:
  pkg.installed:
    - name: icinga2
  service.running:
    - enable: True
    - reload: True
    - require:
      - user: icinga-user

# Install plugins (official + our own)
monitoring-plugin-pkgs:
  pkg.installed:
    - pkgs:
      - monitoring-plugins
      - nagios-plugins-contrib
      - libyaml-syck-perl
      - libmonitoring-plugin-perl
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

# Install sudoers file for Icinga2 checks
/etc/sudoers.d/icinga2:
  file.managed:
    - source: salt://icinga2/icinga2.sudoers
    - mode: 0440

icinga-user:
  user.present:
    - name: nagios
    - groups:
      - nagios
      - ssl-cert
    - require:
      - pkg: icinga2

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
    - template: jinja
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2


# Install host cert + key readable for icinga
/etc/icinga2/pki/{{ grains['id']  }}.crt:
  file.symlink:
    - target: /etc/ssl/certs/{{ grains['id'] }}.cert.pem
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2

/etc/icinga2/pki/{{ grains['id']  }}.key:
  file.symlink:
    - target: /etc/ssl/private/{{ grains['id'] }}.key.pem
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2
/etc/icinga2/pki/ca.crt:
  file.symlink:
   - target: /etc/ssl/certs/ffmuc-cacert.pem 

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
    - template: jinja
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
/etc/icinga2/ffmuc-conf.d:
  file.directory:
    - makedirs: true
    - require:
      - pkg: icinga2


################################################################################
#                               Icinga2 Server                                 #
################################################################################
{% if 'monitoring' in role and 'icinga2_server' in salt['pillar.get']('netbox:config_context:roles') %}

# Install command definitions
/etc/icinga2/ffmuc-conf.d/services:
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
Create /etc/icinga2/ffmuc-conf.d/hosts/generated/:
  file.directory:
    - name: /etc/icinga2/ffmuc-conf.d/hosts/generated/
    - makedirs: true
    - require:
      - pkg: icinga2

Cleanup /etc/icinga2/ffmuc-conf.d/hosts/generated/:
  file.directory:
    - name: /etc/icinga2/ffmuc-conf.d/hosts/generated/
    - clean: true
    - watch_in:
      - service: icinga2

  # Generate config file for every client known to pillar
{% for node_id,data in salt['mine.get']('netbox:config_context:roles:icinga2_client', 'minion_id', tgt_type='pillar').items() %}
/etc/icinga2/ffmuc-conf.d/hosts/generated/{{ node_id }}.conf:
  file.managed:
    - source: salt://icinga2/host.conf.tmpl
    - template: jinja
    - context:
      node_id: {{ node_id }}
      node_config: {{ data }}
    - require:
      - file: Create /etc/icinga2/ffmuc-conf.d/hosts/generated/
    - require_in:
      - file: Cleanup /etc/icinga2/ffmuc-conf.d/hosts/generated/
    - watch_in:
      - service: icinga2
  {% endfor %}

/etc/icinga2/scripts/mattermost-notifications.py:
  file.managed:
    - source: salt://icinga2/mattermost-notifications.py
    - template: jinja
    - mode: 755
    - user: root
    - group: root

/etc/icinga2/conf.d/commands.conf:
  file.managed:
    - source: salt://icinga2/commands.conf
    - mode: 644
    - user: root
    - group: root
    - watch_in:
      - service: icinga2

/etc/icinga2/conf.d/notifications.conf:
  file.managed:
    - source: salt://icinga2/notifications.conf
    - mode: 644
    - user: root
    - group: root
    - watch_in:
      - service: icinga2

/etc/icinga2/conf.d/templates.conf:
  file.managed:
    - source: salt://icinga2/templates.conf
    - mode: 644
    - user: root
    - group: root
    - watch_in:
      - service: icinga2

/etc/icinga2/conf.d/users.conf:
  file.managed:
    - source: salt://icinga2/users.conf.tmpl
    - mode: 644
    - user: root
    - group: root
    - template: jinja
    - watch_in:
      - service: icinga2



# Create configuration for network devices
Create /etc/icinga2/ffmuc-conf.d/net/wbbl/:
  file.directory:
    - name: /etc/icinga2/ffmuc-conf.d/net/wbbl/
    - makedirs: true
    - require:
      - pkg: icinga2

Cleanup /etc/icinga2/ffmuc-conf.d/net/wbbl/:
  file.directory:
    - name: /etc/icinga2/ffmuc-conf.d/net/wbbl/
    - makedirs: true
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2

  # Generate config files for every WBBL device known to pillar
  {% for link_id, link_config in salt['pillar.get']('net:wbbl', {}).items () %}
/etc/icinga2/ffmuc-conf.d/net/wbbl/{{ link_id }}.conf:
  file.managed:
    - source: salt://icinga2/wbbl.conf.tmpl
    - template: jinja
    - context:
      link_id: {{ link_id }}
      link_config: {{ link_config }}
    - require:
      - file: Create /etc/icinga2/ffmuc-conf.d/net/wbbl/
    - require_in:
      - file: Cleanup /etc/icinga2/ffmuc-conf.d/net/wbbl/
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
    - template: jinja
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
/etc/icinga2/ffmuc-conf.d/bird_ospf_interfaces_down_ok.txt:
  file.managed:
    - source: salt://icinga2/bird_ospf_interfaces_down_ok.txt.tmpl
    - template: jinja
    - require:
      - file: /etc/icinga2/ffmuc-conf.d
{% endif %}

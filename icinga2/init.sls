#
# Icinga2
#
{% set roles = salt['pillar.get']('node:roles', []) %}

include:
  - apt
  - sudo
  - needrestart

/etc/apt/trusted.gpg.d/icinga.gpg:
  file.managed:
    - source: salt://icinga2/icinga.gpg

/etc/apt/sources.list.d/icinga.list:
  file.managed:
    - source: salt://icinga2/icinga.list.tmpl
    - template: jinja
    - require:
      - file: /etc/apt/trusted.gpg.d/icinga.gpg

# Install icinga2 package
icinga2:
  pkg.installed:
    - name: icinga2
    - require:
      - file: /etc/apt/sources.list.d/icinga.list
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
      - libmonitoring-plugin-perl
      - curl
      - lsof
      - python3-dnspython
      - python3-tz
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


# Icinga2 master config (for master and all nodes)
/etc/icinga2/icinga2.conf:
  file.managed:
    - source:
      - salt://icinga2/icinga2.conf.H_{{ grains.id }}
      - salt://icinga2/icinga2.conf.{{ grains.os }}.{{ grains.oscodename }}
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

{% if grains['id'] in ["icinga2.in.ffho.net"] %}
/etc/icinga2/secrets.conf:
  file.managed:
    - source: salt://icinga2/secrets.conf.tmpl
    - template: jinja
    - mode: 600
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2
{% endif %}

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


# Install CA cert + host cert + key readable for icinga
/var/lib/icinga2/certs:
  file.directory:
    - makedirs: True

/var/lib/icinga2/certs/ca.crt:
  file.managed:
    - source: salt://certs/ffho-cacert.pem
    - user: nagios
    - group: nagios
    - mode: 644
    - require:
      - pkg: icinga2
      - file: /var/lib/icinga2/certs
    - watch_in:
      - sevice: icinga2

{% set pillar_name = 'node:certs:' ~ grains['id'] %}
/var/lib/icinga2/certs/{{ grains['id'] }}.crt:
  file.managed:
    - contents_pillar: {{ pillar_name }}:cert
    - user: nagios
    - group: nagios
    - mode: 644
    - require:
      - pkg: icinga2
      - file: /var/lib/icinga2/certs
    - watch_in:
      - service: icinga2

/var/lib/icinga2/certs/{{ grains['id'] }}.key:
  file.managed:
    - contents_pillar: {{ pillar_name }}:privkey
    - user: nagios
    - group: nagios
    - mode: 440
    - require:
      - pkg: icinga2
      - file: /var/lib/icinga2/certs
    - watch_in:
      - service: icinga2


# Activate Icinga2 features: API
{% for feature in ['api'] %}
/etc/icinga2/features-enabled/{{ feature }}.conf:
  file.symlink:
    - target: "../features-available/{{ feature }}.conf"
    - user: nagios
    - group: nagios
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
/etc/icinga2/ffho-conf.d:
  file.directory:
    - makedirs: true
    - require:
      - pkg: icinga2


################################################################################
#                               Icinga2 Server                                 #
################################################################################
{% if 'icinga2server' in roles %}

# Link ffho-conf.d as master zone
/etc/icinga2/zones.d/master:
  file.symlink:
    - target: "/etc/icinga2/ffho-conf.d/"
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2

# Users and Notifications
/etc/icinga2/ffho-conf.d/users.conf:
  file.managed:
    - source: salt://icinga2/users.conf.tmpl
    - template: jinja
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2

/etc/icinga2/ffho-conf.d/notifications.conf:
  file.managed:
    - source: salt://icinga2/notifications.conf.tmpl
    - template: jinja
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2

# Install command definitions
/etc/icinga2/ffho-conf.d/services:
  file.recurse:
    - source: salt://icinga2/services
    - file_mode: 644
    - dir_mode: 755
    - user: root
    - group: root
    - clean: true
    - template: jinja
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
    - watch_in:
      - service: icinga2

  # Generate config file for every client known to pillar
  {% for node_id, node_config in salt['pillar.get']('nodes', {}).items () %}
    {# Only monitor hosts which are active or staged. #}
    {% if node_config.get ('status', '') not in [ '', 'active', 'staged' ] %}
      {% continue %}
    {% endif %}

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
  {% endfor %}


# Create configuration for network devices
Create /etc/icinga2/ffho-conf.d/net/wbbl/:
  file.directory:
    - name: /etc/icinga2/ffho-conf.d/net/wbbl/
    - makedirs: true
    - require:
      - pkg: icinga2

Cleanup /etc/icinga2/ffho-conf.d/net/wbbl/:
  file.directory:
    - name: /etc/icinga2/ffho-conf.d/net/wbbl/
    - clean: true
    - watch_in:
      - service: icinga2

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
      - file: Create /etc/icinga2/ffho-conf.d/net/wbbl/
    - require_in:
      - file: Cleanup /etc/icinga2/ffho-conf.d/net/wbbl/
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

# Client should not notify by themselves
/etc/icinga2/features-enabled/notification.conf:
  file.absent:
    - require:
      - pkg: icinga2
    - watch_in:
      - service: icinga2

{% endif %}


################################################################################
#                              Check related stuff                             #
################################################################################

salt-cron-state-apply:
  cron.present:
    - identifier: SALT_CRON_STATE_APPLY
    - name: "/usr/bin/salt-call state.highstate --state-verbose=False test=True > /var/cache/salt/state_apply.tmp 2>/dev/null ; mv /var/cache/salt/state_apply.tmp /var/cache/salt/state_apply"
    - user: root
    - minute: random
    - hour: "*/6"


#
# SSH configuration
#

{% set user_groups = salt['pillar.get']('netbox:config_context:ssh_user_keys') %}
{% set user_home = salt['pillar.get']('netbox:config_context:user_home') %}

# Install ssh server
ssh:
  pkg.installed:
    - name: 'openssh-server'
  service.running:
    - enable: True
    - reload: True


# Enforce pubkey auth (disable password auth) and reload server on config change
/etc/ssh/sshd_config:
  file.managed:
    - source:
      - salt://ssh/sshd_config.{{ grains.os }}.{{ grains.oscodename }}
      - salt://ssh/sshd_config
    - user: root
    - group: root
    - mode: 644
    - watch_in:
      - service: ssh

{#
{% for group in user_groups|sort %}
{% for user in user_groups[group]|sort %}
  {% if user not in user_home %}
    {% set path = '/home/' ~ user %}
  {% else %}
    {% set path = user_home[user] %}
  {% endif %}

# Create Groups
{%- if 'system_users' not in group %}
group-{{ user }}:
  group.present:
      - name: {{ user }}
{% endif %}

# Create SSH User
ssh-{{ user }}:
  user.present:
    - name: {{ user }}
    - shell: /bin/bash
    - home: {{ path }}
    - createhome: True
    {%- if 'system_users' in group %}
    - groups: 
      - nogroup
    - system: True
    {% else %}
    {% if 'Ubuntu' in grains.lsb_distrib_id %}
    - usergroup: False
    {% else %}
    - gid_from_name: True
    {% endif %}
    - system: False
    {%- endif -%}
    {%- if 'admins' in group %}
    - groups:
      - sudo
    {%- endif %}
    {%- if 'system_users' not in group %}
    - require:
      - group: group-{{ user }}
    {% endif %}

# Create .ssh folder for user
{{ path }}/.ssh:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - mode: 700
    - require:
      - user: ssh-{{ user }}

# Create and fill users authorized_keys
{{ path }}/.ssh/authorized_keys:
  file.managed:
    - user: {{ user }}
    - group: {{ user }}
    - contents:
      - {{ user_groups[group][user]  }}
    - mode: 644
    - require:
      - file: {{ path }}/.ssh
{{ path }}/.ssh/authorized_keys2:
  file.absent
{% endfor %}
{% endfor %}


# Create /root/.ssh folder
/root/.ssh:
  file.directory:
    - user: root
    - group: root
    - mode: 700

# Generate /root/.ssh/authorized_keys
/root/.ssh/authorized_keys:
  file.managed:
    - source: salt://ssh/authorized_keys.tmpl
    - template: jinja
    - user: root
    - group: root
    - mode: 0644
    - require:
      - file: /root/.ssh
#}

/root/.ssh/authorized_keys2:
  file.absent

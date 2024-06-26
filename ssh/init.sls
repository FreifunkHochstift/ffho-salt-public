#
# SSH configuration
#

{% set node_config = salt['pillar.get']('node') %}

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

{% set users = ['root'] %}
{% for user, user_config in node_config.get('ssh', {}).items() if user not in ['host'] and user not in users %}
  {% do users.append(user) %}
{% endfor %}

{% for user in users %}
  {% set path = '/' + user %}
  {% if user not in ['root'] %}
    {% set path = '/home' + path %}
  {% endif %}

{# Create user if not present#}
ssh-{{ user }}:
  user.present:
    - name: {{ user }}
    - shell: /bin/bash
    - home: {{ path }}
    - createhome: True
    - usergroup: True
    - system: False

{# Create .ssh dir #}
{{ path }}/.ssh:
  file.directory:
    - user: {{ user }}
    - group: {{ user }}
    - mode: 700
    - require:
      - user: ssh-{{ user }}

{# Create authorized_keys for user (MASTER + host specific) #}
{{ path }}/.ssh/authorized_keys:
  file.managed:
    - source: salt://ssh/authorized_keys.tmpl
    - template: jinja
      username: {{ user }}
    - user: {{ user }}
    - group: {{ user }}
    - mode: 644
    - require:
      - file: {{ path }}/.ssh

  {% if user in node_config.get('ssh', {}) %}
    {% set user_config = node_config.get('ssh:' + user, {}) %}
{# Add SSH-Keys for user #}
{{ path }}/.ssh/id_rsa:
  file.managed:
    - contents_pillar: node:ssh:{{ user }}:privkey
    - user: {{ user }}
    - group: {{ user }}
    - mode: 600
    - require:
      - file: {{ path }}/.ssh

{{ path }}/.ssh/id_rsa.pub:
  file.managed:
    - contents_pillar: node:ssh:{{ user }}:pubkey
    - user: {{ user }}
    - group: {{ user }}
    - mode: 644
    - require:
      - file: {{ path }}/.ssh
  {% endif %}
{% endfor %}

# Manage host keys
{% for key in node_config.get('ssh', {}).get('host', {}) if key in ['dsa', 'ecdsa', 'ed25519', 'rsa'] %}
/etc/ssh/ssh_host_{{ key }}_key:
  file.managed:
    - contents_pillar: node:ssh:host:{{ key }}:privkey
    - mode: 600
    - watch_in:
      - service: ssh

/etc/ssh/ssh_host_{{ key }}_key.pub:
  file.managed:
    - contents_pillar: node:ssh:host:{{ key }}:pubkey
    - mode: 644
    - watch_in:
      - service: ssh
{% endfor %}

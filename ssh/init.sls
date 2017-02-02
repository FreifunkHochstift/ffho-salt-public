#
# SSH configuration
#

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


# Create .ssh dir for user root
/root/.ssh:
  file.directory:
    - user: root
    - group: root
    - mode: 700
    - makedirs: True


# Create authorized_keys for root (MASTER + host specific)
/root/.ssh/authorized_keys:
  file.managed:
    - source: salt://ssh/authorized_keys.tmpl
    - template: jinja
      username: root
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: /root/.ssh

# Add SSH-Keys
{% if 'root' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':ssh', []) %}
/root/.ssh/id_rsa:
  file.managed:
    - contents_pillar: nodes:{{ grains['id'] }}:ssh:root:privkey
    - user: root
    - group: root
    - mode: 600
    - require:
      - file: /root/.ssh

/root/.ssh/id_rsa.pub:
  file.managed:
    - contents_pillar: nodes:{{ grains['id'] }}:ssh:root:pubkey
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: /root/.ssh
{% endif %}

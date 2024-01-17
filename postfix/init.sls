#
# Postfix
#

# Make sure 'mail' is present
bsd-mailx:
  pkg.installed:
    - name: bsd-mailx

postfix:
  pkg.installed:
    - name: postfix
    - require:
      - file: /etc/mailname
  service.running:
    - enable: true
    - reload: true

#
# Don't listen on port 25, by default, a unix socket is enough.
/etc/postfix/master.cf:
  file.managed:
    - source:
      - salt://postfix/master.cf.H_{{ grains['id'] }}
      - salt://postfix/master.cf.{{ grains.os }}.{{ grains.oscodename }}
      - salt://postfix/master.cf
    - watch_in:
      - service: postfix


/etc/postfix/main.cf:
  file.managed:
    - source:
      - salt://postfix/main.cf.H_{{ grains['id'] }}
      - salt://postfix/main.cf.{{ grains.os }}.{{ grains.oscodename }}
      - salt://postfix/main.cf
    - template: jinja
    - watch_in:
      - service: postfix

#
# Send root mail to pillar <globals:ops_mail>
/etc/aliases:
  file.managed:
    - source:
      - salt://postfix/aliases.H_{{ grains['id'] }}
      - salt://postfix/aliases
    - template: jinja
    - context:
      root_mail_address: {{ salt['pillar.get']('globals:ops_mail') }}

newaliases:
  cmd.wait:
    - name: /usr/bin/newaliases
    - watch:
      - file: /etc/aliases


# Set mailname to node_id if not specified otherwise in node pillar.
{% set mailname = salt['pillar.get']('nodes:' ~ grains['id'] ~ ':mailname', grains['id']) %}
/etc/mailname:
  file.managed:
    - contents: "{{ mailname }}"


#
# Manage virtual domains and aliases on MX nodes
#
{% if 'mx' in salt['pillar.get']('nodes:' ~ grains['id'] ~ ':roles', []) %}
/etc/postfix/virtual-domains:
  file.managed:
    - source: salt://postfix/virtual-domains

postmap_domains:
  cmd.wait:
    - name: /usr/sbin/postmap /etc/postfix/virtual-domains
    - watch:
      - file: /etc/postfix/virtual-domains


/etc/postfix/virtual-aliases:
  file.managed:
    - source: salt://postfix/virtual-aliases

postmap_aliases:
  cmd.wait:
    - name: /usr/sbin/postmap /etc/postfix/virtual-aliases
    - watch:
      - file: /etc/postfix/virtual-aliases


/etc/postfix/mynetworks:
  file.managed:
    - source: salt://postfix/mynetworks
{% endif %}

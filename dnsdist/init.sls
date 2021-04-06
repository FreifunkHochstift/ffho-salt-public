#
# dnsdist
#
{% if 'dnsdist' in salt['pillar.get']('netbox:tag_list', []) %}

dnsdist-repo:
  pkgrepo.managed:
    - name: deb [arch=amd64] http://repo.powerdns.com/{{ grains.lsb_distrib_id | lower }} {{ grains.oscodename }}-dnsdist-15 main
    - clean_file: True
    - key_url: https://repo.powerdns.com/FD380FBB-pub.asc
    - file: /etc/apt/sources.list.d/dnsdist.list

dnsdist:
  pkg.installed:
    - refresh: True
    - require:
      - pkgrepo: dnsdist-repo
  service.running:
    - enable: True
    - restart: True
    - require:
      - file: /etc/dnsdist/dnsdist.conf
      - file: /var/lib/dnsdist
      - file: dnsdist-service-override
    - watch:
      - file: dnsdist-service-override

/etc/dnsdist/dnsdist.conf:
  file.managed:
    - source: salt://dnsdist/dnsdist.conf.j2
    - template: jinja
    - require:
        - pkg: dnsdist

/var/lib/dnsdist:
  file.directory:
    - user: _dnsdist
    - group: _dnsdist
    - require:
      - pkg: dnsdist

dnsdist-service-override:
  file.managed:
    - name: /etc/systemd/system/dnsdist.service.d/override.conf
    - source: salt://dnsdist/dnsdist.override.service
    - makedirs: True

{%- if 'webfrontend' in grains.id %}
# to allow reading ssl cert
add_dnsdist_group_ssl-cert:
  user.present:
    - name: _dnsdist
    - groups:
      - ssl-cert
{% endif %}{# if 'webfrontend' #}

{% endif %}{# if 'dnsdist' in tag_list #}

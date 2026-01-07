#
# opensearch
#

opensearch2x:
  pkgrepo.managed:
    - humanname: Opensearch
    - name: deb [signed-by=/usr/share/keyrings/opensearch-keyring] https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/apt stable main
    - file: /etc/apt/sources.list.d/opensearch.list
    - key_url: https://artifacts.opensearch.org/publickeys/opensearch.pgp

/etc/apt/preferences.d/opensearch:
  file.managed:
    - source: salt://opensearch/apt-pin-opensearch.tmpl
    - template: jinja
    - context:
      opensearch_version: {{ opensearch_version }}

opensearch:
  pkg.installed:
    - pkgs:
      - opensearch: {{ opensearch_version }}
  service.running:
    - name: opensearch
    - enable: True
    - require:
      - file: /etc/opensearch/opensearch.yml
    - watch:
      - file: /etc/opensearch/opensearch.yml

/etc/opensearch/opensearch.yml:
  file.managed:
    - source: 
      - salt://opensearch/opensearch.yml.H_{{grains['id']}}
      - salt://opensearch/opensearch.yml
    - template: jinja


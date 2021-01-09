#
# elasticsearch
#

elasticsearch7x:
  pkgrepo.managed:
    - humanname: Elasticsearch 7.x
    - name: deb https://artifacts.elastic.co/packages/oss-7.x/apt stable main
    - file: /etc/apt/sources.list.d/elastic-7.x.list
    - key_url: https://artifacts.elastic.co/GPG-KEY-elasticsearch

elasticsearch:
  pkg.installed:
    - name: elasticsearch-oss
  service.running:
    - name: elasticsearch
    - enable: True
    - require:
      - file: /etc/elasticsearch/elasticsearch.yml
    - watch:
      - file: /etc/elasticsearch/elasticsearch.yml

/etc/elasticsearch/elasticsearch.yml:
  file.managed:
    - source: 
      - salt://elasticsearch/elasticsearch.yml.H_{{grains['id']}}
      - salt://elasticsearch/elasticsearch.yml


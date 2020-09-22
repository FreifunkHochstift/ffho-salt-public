###
# install jibri
###
{%- from "jitsi/map.jinja" import jitsi with context %}

{% if jitsi.jibri.enabled %}

google-chrome-repo:
  pkgrepo.managed:
    - humanname: Google Chrome Repo
    - name: deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main
    - file: /etc/apt/sources.list.d/google-chrome.list
    - key_url: https://dl-ssl.google.com/linux/linux_signing_key.pub

jibri:
  pkg.installed:
    - require:
      - pkgrepo: jitsi-repo
  service.running:
    - enable: True
    - reload: True

google-chrome-stable:
  pkg.installed:
    - require:
      - pkgrepo: google-chrome-repo

chromedriver-binary:
  archive.extracted:
    - name: /usr/local/bin/chromedriver
    - source: https://chromedriver.storage.googleapis.com/{{ jitsi.jibri.chromedriver_version }}/chromedriver_linux64.zip
    - overwrite: True
    - mode: 0755
    #- if_missing: /usr/local/bin/chromedriver

/etc/jitsi/jibri/config.json:
  file.managed:
    - source: jitsi/jibri/config.json.jinja
    - template: jinja

{% endif %} # jibri.enabled
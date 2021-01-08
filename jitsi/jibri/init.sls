###
# install jibri
###
{%- from "jitsi/map.jinja" import jitsi with context %}

{% if jitsi.jibri.enabled %}

include:
  - jitsi.base

google-chrome-repo:
  pkgrepo.managed:
    - humanname: Google Chrome Repo
    - name: deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main
    - file: /etc/apt/sources.list.d/google-chrome.list
    - key_url: https://dl-ssl.google.com/linux/linux_signing_key.pub

snd_aloop:
  kmod.present:
    - persist: True

jibri:
  pkg.installed:
    - require:
      - pkgrepo: jitsi-repo
  service.running:
    - enable: True
    - require:
      - file: /etc/jitsi/jibri/config.json
    - watch:
      - file: /etc/jitsi/jibri/config.json

google-chrome-stable:
  pkg.latest:
    - require:
      - pkgrepo: google-chrome-repo

setup_chromedriver_update_script:
  file.managed:
    - name: /usr/local/bin/update_chromedriver.sh
    - source: salt://jitsi/jibri/update_chromedriver.sh
    - mode: 0755

execute_chromedriver_update:
  cmd.run:
    - name: /usr/local/bin/update_chromedriver.sh

/etc/jitsi/jibri/config.json:
  file.managed:
    - source: salt://jitsi/jibri/config.json.jinja
    - template: jinja

{% else %}
google-chrome-stable:
  pkg.removed
google-chrome-repo:
  pkgrepo.absent:
    - name: deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main
jibri:
  pkg.removed
/etc/jitsi/jibri:
  file.absent
{% endif %} # jibri.enabled

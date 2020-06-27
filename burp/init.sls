#
# Burp backup
#

include:
 - certs

/etc/apt/trusted.gpg.d/burp.gpg:
  file.managed:
    - source: salt://burp/burp.gpg

/etc/apt/sources.list.d/burp.list:
  file.managed:
    - source: salt://burp/burp.list.tmpl
    - template: jinja
    - require:
      - file: /etc/apt/trusted.gpg.d/burp.gpg

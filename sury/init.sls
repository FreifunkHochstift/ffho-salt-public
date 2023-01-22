#
# sury php
#

/etc/apt/trusted.gpg.d/deb.sury.org-php.gpg:
  file.managed:
    - source: salt://sury/sury.gpg

/etc/apt/sources.list.d/sury.php.list:
  file.managed:
    - source: salt://sury/sury.list.tmpl
    - template: jinja
    - require:
      - file: /etc/apt/trusted.gpg.d/deb.sury.org-php.gpg

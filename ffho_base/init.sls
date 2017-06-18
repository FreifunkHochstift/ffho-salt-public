#
# Stuff for every f*cking FFHO machine
#

ffho_packages:
  pkg.installed:
    - pkgs:
      - git
      - openssl
      - netcat-openbsd

/usr/local/bin/ff_log_to_bot:
  file.managed:
    - source: salt://ffho_base/ff_log_to_bot
    - template: jinja
    - mode: 755

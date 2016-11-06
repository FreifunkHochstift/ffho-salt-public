# Conveniance bat-hosts file for informative batctl output
/etc/bat-hosts:
  file.managed:
    - source: salt://batman/bat-hosts.tmpl
    - template: jinja

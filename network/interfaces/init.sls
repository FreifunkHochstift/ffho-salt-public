#
# network.interfaces
#
# Generate and install /etc/network/interfaces file
#

/etc/network/interfaces:
 file.managed:
    - template: jinja
    - source: salt://network/interfaces/interfaces.tmpl

#
# Burp backup - Repo
#

burp-repo:
  pkgrepo.managed:
    - name: deb http://ziirish.info/repos/debian/{{ grains.oscodename }}/ zi-latest main
    - clean_file: True
    - file: /etc/apt/sources.list.d/burp.list
    - keyserver: keys.gnupg.net
    - keyid: A1718780C58CD6E3
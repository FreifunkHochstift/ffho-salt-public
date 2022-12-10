#
# Manage root user (password)
#

# This should break, when the pillar isn't present
{% set root_pw_hash = pillar['globals']['root_password_hash'] %}

root:
  user.present:
    - fullname: root
    - uid: 0
    - gid: 0
    - home: /root
    - password: {{ root_pw_hash }}
    - enforce_password: True
    - empty_password: False

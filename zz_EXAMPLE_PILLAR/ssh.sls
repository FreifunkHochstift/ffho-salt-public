ssh:
  keys:
#
#   <user ID>:
#     pubkeys:
#       - "<ssh public key string>"
#       - "<optional 2nd public key>"
#     access:
#
# Option 1: Access for <username> on all nodes
#
#       <username>: global
#
# Option 2: Access for <username> on list of given nodes:
#
#       <username>:
#         nodes:
#           - node1.in.ffho.net
#           - node2.in.ffho.net
#
# Option 3: Access as <username> on all nodes matching at least one of tht
#           given roles:
#
#        <username>:
#          roles:
#            - webserver
#            - router
#
#
# Examples:
#
    max:
      pubkeys:
        - "ssh-rsa ABC max@pandora"
      access:
        root: global

    karsten:
      pubkeys:
        - "ssh-rsa ACBDE kb-light@leo-loewe"
      access:
        root:
          global: true
        build:
          nodes:
            - masterbuilder.in.ffho.net

    webmaster:
      pubkeys:
        - "ssh-rsa AAAfoo webmaster@apache"
      access:
        root:
          roles:
            - webserver
          nodes:
            - fe01.in.ffho.net

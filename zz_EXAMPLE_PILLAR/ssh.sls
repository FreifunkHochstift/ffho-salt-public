ssh:
  keys:
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

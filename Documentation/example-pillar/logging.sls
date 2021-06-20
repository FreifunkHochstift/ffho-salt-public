#
# Logging related config
#

logging:

  # Config for (r)syslog
  syslog:

    # Central logserver every node should send logs to
    logserver:  "<IP or FQDN>"

  # Config for Graylog
  graylog:

    # IP of the graylog entry point
    syslog_uri: "<URI>"

    # password secret
    password_secret: "<secret>"

    root_password_sha2: "<hash>"

    root_username: "<username>"

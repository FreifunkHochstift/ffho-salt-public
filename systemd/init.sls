#
# systemd related stuff
#

# Define systemd daemon-reload command to pull in if required
systemctl-daemon-reload:
  cmd.wait:
    - name: systemctl daemon-reload
    - watch: []

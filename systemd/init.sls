#
# systemd related stuff
#

# Define systemd daemon-reload command to pull in if required
systemctl-daemon-reload:
  cmd.wait:
    - name: systemctl daemon-reload
    - watch: []


#
# Install service to wait for routing adjancies to come up (if needed)
#
/etc/systemd/system/wait-for-routes.service:
  file.managed:
    - source: salt://systemd/wait-for-routes.service
    - watch_in:
      - cmd: systemctl-daemon-reload

wait-for-routes.service:
  service.running:
    - enable: true
    - require:
      - file: /etc/systemd/system/wait-for-routes.service
      - file: /usr/local/sbin/wait-for-routes

/usr/local/sbin/wait-for-routes:
  file.managed:
   - source: salt://systemd/wait-for-routes
   - mode: 755


#
# Unfuck systemd defaults likely to break stuff
#
{% if grains.oscodename == "bullseye" %}
/etc/systemd/network/90-unfuck-mac-overwrite.link:
  file.managed:
    - source: salt://systemd/90-unfuck-mac-overwrite.link
    - watch_in:
      - cmd: systemctl-daemon-reload
{% endif %}

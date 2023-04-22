#!/bin/sh
#
# Maximilian Wilhelm <max@sdn.clinic>
#  --  Fri, 14 Apr 2023 22:05:24 +0200
#

while ! salt-call test.ping >/dev/null 2>&1; do
	echo "Please accept minion key on Salt master."
	sleep 10
done

################################################################################
#                           Set up screeen and SSH                             #
################################################################################

echo "Syncing modules..."
salt-call saltutil.sync_all

echo "Configuring screen and SSH..."
salt-call state.apply screen,ssh

echo "Running highstate..."
salt-call state.highstate

systemctl disable ffho-first-boot.service

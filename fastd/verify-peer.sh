#!/bin/bash

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

if [ -n "$(cat /etc/fastd/peers-blacklist | grep "$1")" ]; then
	echo -e "$(timestamp)\t$1\t$2\tblocked" >> /var/log/fastd.blacklist;
	exit 1;
else
	exit 0;
fi

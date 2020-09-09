#!/bin/bash
WORKDIR=/var/lib/influxdb/backup
# check if we are the user influxdb
if [ ! "$(whoami)" == "influxdb" ] ; then
	echo "This script must run as user influxdb"
	exit 1
fi

# Create workdir if it does not exist
[ ! -d ${WORKDIR} ] && mkdir ${WORKDIR}

pushd ${WORKDIR} > /dev/null
if [ -d $(date -I) ] ; then
        echo "Backupdirectory for today already exists. I refuse to do anything"
        exit 1
fi

echo "Backup"
influxd backup -portable $(date -I)
echo "Backup finished"
ehco "--------------------------------------------"
echo "Cleanup"
find ${WORKDIR} -ctime +2 -delete

popd > /dev/null

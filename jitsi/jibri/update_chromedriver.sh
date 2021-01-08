#!/bin/bash

CHROME_DRIVER_VERSION=`curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE`
if grep $CHROME_DRIVER_VERSION /etc/jitsi/jibri/chromedriver.version 1>/dev/null 2>&1 ; then
    echo "Latest version already installed"
    exit 0
fi

echo $CHROME_DRIVER_VERSION > /etc/jitsi/jibri/chromedriver.version
wget -N http://chromedriver.storage.googleapis.com/$CHROME_DRIVER_VERSION/chromedriver_linux64.zip -P ~/
unzip ~/chromedriver_linux64.zip -d ~/
rm ~/chromedriver_linux64.zip
sudo mv -f ~/chromedriver /usr/local/bin/chromedriver
sudo chown root:root /usr/local/bin/chromedriver
sudo chmod 0755 /usr/local/bin/chromedriver
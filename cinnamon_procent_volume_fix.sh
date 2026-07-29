#!/bin/bash
# Cinnamon - Volume Procent fix - Utility
# Author: Michael Janssen <m.janssen@lyrah.net>
# License: GPLv3 (See README.md for details)

VERSION="1.0-0"


FOLDER="/usr/share/cinnamon/js/ui"
FILE="osdWindow.js"
LINE="this.setLabel(value.toString() + ' %');"
TIMESTAMP=$(date +%F-%H_%M-%Z)

# check if script is running as root
if [ "$(whoami)" != "root" ]; then
	echo "ERROR : This script must be started as root!"
	sleep 2
	exit 1
fi

#check file to exist
if [ -e "$FOLDER"/"$FILE" ]
	then
	#check for line in config
	if ! grep -q "$LINE" "$FOLDER"/"$FILE"
	then
		#create backup
		cp -av "$FOLDER"/"$FILE" /var/backups/"$FILE"."$TIMESTAMP"
		#insert line into config
	    sed -i "/if (this._level.visible) {/a\        $LINE" "$FOLDER"/"$FILE"
		echo "OSD-Fix installed."
	else
		echo "OSD-Fix already installed."
	fi
else
	echo "ERROR : File not found : $FOLDER/$FILE !"
	exit 1
fi
exit 0

#!/bin/bash

# System Update Script
# Author: Michael Janssen <m.janssen@lyrah.net>
# License: GPLv3 (See README.md for details)

VERSION="1.3-1"

TMPFILE="/tmp/sysupdater.log"
NOTIFYMODE="POPUP"
AUTOREBOOT="NO"
UPDATEMOTD="NO"
# set empty if not wanted
DOCKER_PATH="/srv/docker"
DOCKER_RESTART="0"

# Mailvars
SMTPSERVER="mail.local"
SMTPPORT="587"
SMTPUSER="sender@mail.local"
SMTPPASS='xxxxxxxxxxxxxxx'
FROMNAME="sender"
MAILFROM="sender@mail.local"
MAILTO=(mail1@mail.local mail2@mail.local)
SUBJECT="Systemupdate performed! System rebooted! - $(/usr/bin/hostname -f)!"
MESSAGE="Systemupdate has been completed! Autoreboot has been performed!! $(date "+%d.%b.%Y - %H:%M:%S %Z"). Log append."

echo " _______             ___ ___          __       __              "
echo "|   _   .--.--.-----|   Y   .-----.--|  .---.-|  |_.-----.----."
echo "|   1___|  |  |__ --|.  |   |  _  |  _  |  _  |   _|  -__|   _|"
echo "|____   |___  |_____|.  |   |   __|_____|___._|____|_____|__|  "
echo "|:  1   |_____|     |:  1   |__|                               "
echo "|::.. . |           |::.. . |                                  "
echo "--------'           --------'    "
echo "                                         Version : "$VERSION""
echo "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
echo "|A|u|t|o|m|a|t|i|c| |L|i|n|u|x| |U|p|d|a|t|e|s|c|r|i|p|t|"
echo "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
sleep 2

	# Cleanup Tmpfile
	rm -fv $TMPFILE
	touch $TMPFILE

	# Show startingtime for the log
	echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - Starting Systemupdate..."

	# install updates and cleanup
	# renew package lists
	echo "Starting native deb update..."
	apt-get clean
	apt-get update
	apt list --upgradable | tee -a $TMPFILE
	# deb packages
	apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y upgrade
	apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y dist-upgrade
	apt-get autoremove -y | tee -a $TMPFILE

	# update flatpaks
	flatpak update -y | tee -a $TMPFILE

	# update docker
	if [ -n "$DOCKER_PATH" ] && [ -d "$DOCKER_PATH" ]
	then
		COMPOSE_FILES=$(find "$DOCKER_PATH" -type f -iname "docker-compose.yml")
		for i in $COMPOSE_FILES
		do
			echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - Pulling new image for container : $i ..."
			OUT=$(docker compose -f "$i" pull --ignore-pull-failures 2>&1)
			echo "$OUT"

			if echo "$OUT" | grep -Eq 'Downloaded newer image|Pull complete|Status: Downloaded newer image|layers: Pull complete'; then
				UPDATED=1
			else
				UPDATED=0
			fi

			if [ "$DOCKER_RESTART" = "1" ] && [ "$UPDATED" -eq 1 ]
			then
				echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - Restarting compose: $i ."
				docker compose -f "$i" down
				docker compose -f "$i" up -d
			else
				echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - No updates for: $i ."
			fi
			echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - Pulling complete!"
		done
		if [ "$UPDATED" -eq 1 ]
		then
			echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - Cleaning up unused Docker images and build cache..."
			docker image prune -af
			docker builder prune -f
		fi
	fi

	if [[ $NOTIFYMODE == "MAIL" ]]
	then

		# send notify mail
		gzip -k $TMPFILE
		echo "$MESSAGE" | mutt -s "$SUBJECT" -e "set from=$MAILFROM" \
		-e "set smtp_url=smtp://$SMTPUSER@$SMTPSERVER:$SMTPPORT/" \
		-e "set realname=$FROMNMAME" \
		-e "set smtp_pass=$SMTPPASS" -a "$TMPFILE.gz" -- "${MAILTO[@]}"
		rm -fv $TMPFILE.gz

	fi

	if [[ $NOTIFYMODE == "POPUP" ]]
	then
		notify-send -u critical "Systemupdates installed!" "Reboot the system, ASAP!"
	fi

	# we done here
	echo "$0 : Systemupdate complete. Please reboot, asap!"


	if [[ $UPDATEMOTD == "YES" ]]
	then
		# update motd
		cp -av /etc/motd /var/backups/etc_motd_$(date +'%Y-%b-%d')
		gzip /var/backups/etc_motd_$(date +'%Y-%b-%d')
		sed -i "s/^# Last updates installed = .*#\$/# Last updates installed = $(date +'%Y-%b-%d')                          #/" /etc/motd
	fi

if [[ $AUTOREBOOT == "YES" ]]
	then
		# reboot
		echo -n "Reboot in 3..."
		sleep 1
		echo -n "2..."
		sleep 1
		echo "1..."
		sleep 1
		/usr/sbin/shutdown -r now
fi

sleep 1
exit 0

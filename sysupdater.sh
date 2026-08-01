#!/bin/bash

# System Update Script
# Author: Michael Janssen <m.janssen@lyrah.net>
# License: GPLv3 (See README.md for details)

# search for external config and load it
{ source ./adminscripts.cfg || source /etc/adminscripts.cfg || source /usr/local/etc/adminscripts.cfg ; } 2>/dev/null || echo "Warning: No config file found!"

# load version.nfo
{ source ./version.nfo ; } 2>/dev/null || echo "Warning: Version file not found!"

TMPFILE="/tmp/sysupdater.log"

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
	apt-get update | tee -a $TMPFILE
	apt list --upgradable | tee -a $TMPFILE
	# deb packages
	apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y upgrade | tee -a $TMPFILE
	apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y dist-upgrade | tee -a $TMPFILE
	apt-get autoremove -y | tee -a $TMPFILE

	# update flatpaks
	flatpak update -y | tee -a $TMPFILE

	# update docker
	if [ -n "$DOCKER_PATH" ] && [ -d "$DOCKER_PATH" ]
	then
		find "$DOCKER_PATH" -type f -iname "docker-compose.yml" | while read -r i
		do
			echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - Pulling new image for container : $i ..."
			if docker compose -f "$i" pull --ignore-pull-failures 2>&1 | tee /dev/stderr | grep -Eq 'Downloaded newer image|Pull complete|Status: Downloaded newer image|layers: Pull complete'
			then
				echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - Restarting compose: $i ."
				docker compose -f "$i" down
				docker compose -f "$i" up -d
			else
				echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - No updates for: $i ."
			fi
			echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - Pulling complete!"
		done
		echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - Cleaning up unused Docker images and build cache..."
		docker image prune -af
		docker builder prune -f
	fi

	# check for nextcloud upgrade needed
	if docker exec -u www-data nextcloud-app php occ status --output=json 2>/dev/null | grep -q '"needsDbUpgrade":true'
	then
		echo "$0 : $(date '+%d.%b.%Y - %H:%M:%S %Z') - nextcloud upgrade needed..."
		docker exec -u www-data nextcloud-app php occ upgrade --no-interaction
		docker exec -u www-data nextcloud-app php occ app:update --all --no-interaction
		docker exec -u www-data nextcloud-app php occ db:add-missing-indices --no-interaction
		docker exec -u www-data nextcloud-app php occ db:add-missing-columns --no-interaction
		docker exec -u www-data nextcloud-app php occ db:add-missing-primary-keys --no-interaction
	fi

	if [[ $NOTIFYMODE == "MAIL" ]]
	then

		# send notify mail
		gzip -k $TMPFILE
		echo "$MESSAGE" | mutt -s "$SUBJECT" -e "set from=$MAILFROM" \
		-e "set smtp_url=smtp://$SMTPUSER@$SMTPSERVER:$SMTPPORT/" \
		-e "set realname=$FROMNAME" \
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

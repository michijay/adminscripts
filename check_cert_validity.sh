#!/bin/bash

# Check-Cert-Validity for Lets Encrypt
# Author: Michael Janssen <m.janssen@lyrah.net>
# License: GPLv3 (See README.md for details)

VERSION="1.2-0"

# Domainname
DOMAIN="xxx.com"

# Data for notification email
SERVER="mail.local"
FROM="sender@mail.local"
TO="all@mail.local"
USER="sender"
PASS='XXXXXXXXXXX'
CHARSET="utf-8"
SENDEMAIL="/usr/bin/sendemail"
SUBJ="SSL Certificate renewed for $DOMAIN !"
MESSAGE="Certificate renewed, check SSL connection."
CHARSET="utf-8"

# Data for backupjob
BACKUPSERVER="backupserver.local"
BACKUPFOLDER="/media/backupserver"
SERVERSHARE="/media/backup_storage/servers"
MYSQLUSER="backupuser"
MYSQLPASS='XXXXXXXXXXXXX'
MYSQLDUMP="/usr/bin/mysqldump -u $MYSQLUSER -p$MYSQLPASS --all-databases --default-character-set=utf8"

# Certificate data
SSLCONFFILE="/etc/apache2/sites-enabled/port443.conf"
DAYS_TO_RENEW="10"
CERTFILE=$(grep "SSLCertificateFile" $SSLCONFFILE | cut -d" " -f2)
VALIDITY=$(openssl x509 -enddate -noout -in $CERTFILE | cut -d"=" -f2)
DATECURRENT=$(/usr/bin/date "+%b %d %H:%M:%S %Y %Z")
DATE_ACTUALLY_SECONDS=$(date +"%s")
DATE_EXPIRE_SECONDS=$(openssl x509 -enddate -noout -in $CERTFILE | grep "notAfter=" | sed 's/^notAfter=//g' | xargs -I{} date -d {} +%s)
DATE_EXPIRE_FORMAT=$(date -I --date="@${DATE_EXPIRE_SECONDS}")
DATE_DIFFERENCE_SECONDS=$((DATE_EXPIRE_SECONDS - DATE_ACTUALLY_SECONDS))
DATE_DIFFERENCE_DAYS=$((DATE_DIFFERENCE_SECONDS/60/60/24))

	# for logging
	echo "$(date "+%d.%b.%Y - %H:%M:%S %Z") - Start checking SSL-Certificate validity."
	echo "Certfile:	$CERTFILE"
	echo "Valid till:	$VALIDITY"
	echo "Current date:	$DATECURRENT"

	if [ "$DATE_DIFFERENCE_DAYS" -ge "$DAYS_TO_RENEW" ]
	then
		LOGMSG=$(basename "$0")" : $(date "+%d.%b.%Y - %H:%M:%S %Z") : Cert is valid for more than $DAYS_TO_RENEW days! - Renewing the certificate is not necessary."
		echo $LOGMSG
		logger $LOGMSG
		echo "$(date "+%d.%b.%Y - %H:%M:%S %Z") - Finished checking SSL-Certificate validity."
		exit 0
	else
		LOGMSG=$(basename "$0")" : $(date "+%d.%b.%Y - %H:%M:%S %Z") : Cert is valid for less than $DAYS_TO_RENEW days! - Renewing the certificate..."
                echo $LOGMSG
                logger $LOGMSG
		/usr/bin/systemctl stop apache2 && /usr/bin/certbot renew && /usr/bin/systemctl restart apache2
		#$SENDEMAIL -f "$FROM" -t "$TO" -u "$SUBJ" -s "$SERVER" -xu "$USER" -xp "$PASS" -m "$MESSAGE" -v -o message-charset="$CHARSET" -q
		echo "$(date "+%d.%b.%Y - %H:%M:%S %Z") - Finished checking SSL-Certificate validity."

	fi

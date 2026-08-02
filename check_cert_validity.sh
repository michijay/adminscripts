#!/bin/bash

# Check-Cert-Validity for Lets Encrypt
# Author: Michael Janssen <m.janssen@lyrah.net>
# License: GPLv3 (See README.md for details)

# search for external config and load it
{ source ./adminscripts.cfg || source /etc/adminscripts.cfg || source /usr/local/etc/adminscripts.cfg ; } 2>/dev/null || echo "Warning: No config file found!"

# load version.nfo
{ source ./version.nfo || source /opt/adminscripts/version.nfo ; } 2>/dev/null || echo "Warning: Version file not found!"

# Data for notification email
SUBJECT="SSL Certificate renewed for $DOMAIN !"
MESSAGE="Certificate renewed, check SSL connection."
CHARSET="utf-8"

CERTFILE=$(grep "SSLCertificateFile" $SSLCONFFILE | sed 's/^[[:space:]]*//' | cut -d" " -f2)
VALIDITY=$(openssl x509 -enddate -noout -in $CERTFILE | cut -d"=" -f2)
DATECURRENT=$(/usr/bin/date "+%b %d %H:%M:%S %Y %Z")
DATE_ACTUALLY_SECONDS=$(date +"%s")
DATE_EXPIRE_SECONDS=$(openssl x509 -enddate -noout -in $CERTFILE | grep "notAfter=" | sed 's/^notAfter=//g' | xargs -I{} date -d {} +%s)
DATE_EXPIRE_FORMAT=$(date -I --date="@${DATE_EXPIRE_SECONDS}")
DATE_DIFFERENCE_SECONDS=$((DATE_EXPIRE_SECONDS - DATE_ACTUALLY_SECONDS))
DATE_DIFFERENCE_DAYS=$((DATE_DIFFERENCE_SECONDS/60/60/24))

	# for logging
	echo "$0 : $(date "+%d.%b.%Y - %H:%M:%S %Z") - Start checking SSL-Certificate validity."
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
		# send notify mail
		echo "$MESSAGE" | mutt -s "$SUBJECT" -e "set from=$MAILFROM" \
		-e "set smtp_url=smtp://$SMTPUSER@$SMTPSERVER:$SMTPPORT/" \
		-e "set realname=$FROMNAME" \
		-e "set smtp_pass=$SMTPPASS" -- "${MAILTO[@]}"
		echo "$0 : $(date "+%d.%b.%Y - %H:%M:%S %Z") - Finished checking SSL-Certificate validity."

	fi

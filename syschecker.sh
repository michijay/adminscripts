#!/bin/bash

# SysChecker - System intruder and virus checker
# Author: Michael Janssen <m.janssen@lyrah.net>
# License: GPLv3 (See README.md for details)

# search for external config and load it
{ source ./adminscripts.cfg || source /etc/adminscripts.cfg || source /usr/local/etc/adminscripts.cfg ; } 2>/dev/null || echo "Warning: No config file found!"

# load version.nfo
{ source ./version.nfo ; } 2>/dev/null || echo "Warning: Version file not found!"

SCANDIRS=( $(find / -maxdepth 1 -type d | grep -v -E "sys|dev|run|proc|lost\+found|media|mnt|home") )
TMPFILE="/tmp/syschecker.log"

echo "+-+-+-+-+-+-+-+-+-+-+ +-+ +-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+ +-+-+-+ +-+-+-+-+-+-+-+-+-+-+-+-+"
echo "|S|y|s|C|h|e|c|k|e|r| |-| |S|y|s|t|e|m| |i|n|t|r|u|d|e|r| |a|n|d| |v|i|r|u|s|s|c|a|n|n|e|r|"
echo "+-+-+-+-+-+-+-+-+-+-+ +-+ +-+-+-+-+-+-+ +-+-+-+-+-+-+-+-+ +-+-+-+ +-+-+-+-+-+-+-+-+-+-+-+-+"
echo " Version : $VERSION"
sleep 1

if [[ "$1" == "--update" ]]
then
	if [[ "$ROOTKIT_SCAN" == "YES" ]]
	then
		rkhunder --update
	fi
	if [[ "$AV_SCAN" == "YES" ]]
	then
		systemctl stop clamav-freshclam
		freshclam
		systemctl restart clamav-freshclam
	fi	
fi

if [[ "$1" == "--check" ]]
then
	# Cleanup Tmpfile
	rm -rfv $TMPFILE
	touch $TMPFILE

	# Remove root directory from array
	unset SCANDIRS[0]

	if [[ "$AV_SCAN" == "YES" ]]
	then
		# Virusscanning
		echo "$0 : Virusscanning..."
		for i in ${SCANDIRS[@]}
		do
			echo "Scanning : $i"
			nice -n 19 clamscan -ir --scan-archive=no $i | tee -a $TMPFILE
			echo "Scanning complete."
		done
		echo "$0 : Virusscan complete."
	fi

	if [[ "$ROOTKIT_SCAN" == "YES" ]]
	then
		# Rootkit scanning
		echo "$0 : Rootkitscanning..."
		nice -n 19 rkhunter -c --skip-keypress --rwo  | tee -a $TMPFILE
		echo "$0 : Rootkitscan complete."
	fi

	if [[ "$AIDE_SCAN" == "YES" ]]
	then
		# Check for changed files
		echo "$0 : Checking systemintegrity..."
		nice -n 19 aide -c /etc/aide/aide.conf --check
		echo "$0 : SysInt Check complete."
	fi

fi

if [[ "$1" == "--reset-status" ]]
then
	if [[ "$AIDE_SCAN" == "YES" ]]
	then
		aide -c /etc/aide/aide.conf --update
		cp -v /var/lib/aide/aide.db{.new,}
	fi
	if [[ "$ROOTKIT_SCAN" == "YES" ]]
	then
		rkhunter --propupd
	fi
fi

if [[ -z "$1" ]] || [[ "$1" == "--help" ]]
then
	echo "Usage: $0 [OPTION]"
	echo ""
	echo "Options:"
	echo "   --check" "Scan system for viruses, malware and suspicious changes."
	echo "   --update" "Update Virus- and Rootkit-Definitions."
	echo "   --reset-status" "Set current systemstatus as Clean-n-Safe-Status for RKHunter and AIDE."
	echo "   --help" "Show this help message."
	echo ""
	sleep 1
	exit 1
fi

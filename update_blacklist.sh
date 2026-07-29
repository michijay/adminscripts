#!/bin/bash

# --- Configuration ---
NFT_TABLE="inet"
NFT_CHAIN="filter"
NFT_SET="blacklist"

# --- Check argument ---
if [[ -z "$1" ]]; then
	echo "ERROR : Option needed!"
	echo ""
	echo "To add all IPs from a list to the 'blacklist' set :"
	echo "Run : $0 <path_to_ip.lst>"
	echo ""
	echo "To show all current IPs in the 'blacklist' set :"
	echo "Run : $0 -show"
	echo ""
	echo "To cleanup all IPs from the 'blacklist' set :"
	echo "Run : $0 -cleanup"
	exit 1
fi

if [[ "$1" == "-show" ]]; then
	nft list set inet filter blacklist
	exit 0
fi


if [[ "$1" == "-cleanup" ]]; then
	nft flush set inet filter blacklist
	echo "INFO : All IPs have been removed from the 'blacklist' set."
	exit 0
fi

BLACKLIST_FILE="$1"

# --- Check file existence ---
if [[ ! -f "$BLACKLIST_FILE" ]]; then
    echo "ERROR : File '$BLACKLIST_FILE' not found."
    exit 1
fi

# --- Process entries ---
echo "INFO : Reading IPs from: $BLACKLIST_FILE"
while read -r ip; do
    # Skip empty lines and comments
    [[ -z "$ip" || "$ip" =~ ^# ]] && continue

    # Add IP to nftables set (ignore duplicates)
    nft add element $NFT_TABLE $NFT_CHAIN $NFT_SET { $ip } 2>/dev/null \
        && echo "INFO : Added to backlist: $ip" \
        || echo "WARNING : Skipped (possibly already present): $ip"
done < "$BLACKLIST_FILE"

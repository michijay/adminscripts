#!/bin/bash

MAX_TRIES=5
TRIES=0

while [ $TRIES -lt $MAX_TRIES ]; do
    if [ $TRIES -eq 0 ]; then
        PASS_MSG="Enter password for ZFS-Homedrive:"
    else
        PASS_MSG="Enter password for ZFS-Homedrive (failed tries: $TRIES):"
    fi

    if systemd-ask-password "$PASS_MSG" --no-tty | zfs load-key -a; then
        echo "ZFS home drive unlocked successfully."
        exit 0
    else
        echo "Wrong password! Attempt $((TRIES+1)) of $MAX_TRIES."
        ((TRIES++))
    fi
done

echo "Too many failed attempts. System will enter emergency mode."
sleep 3
systemctl emergency

# paranoia mode
#zfs destroy -f antares/home

#!/bin/sh
#
##############################################################################
#
# Fetch weather screensaver from a configurable URL.

# change to directory of this script
cd "$(dirname "$0")"

# load configuration
if [ -e "config.sh" ]; then
	source ./config.sh
else
	TMPFILE=/tmp/tmp.onlinescreensaver.png
fi

# load utils
if [ -e "utils.sh" ]; then
	source ./utils.sh
else
	echo "Could not find utils.sh in `pwd`"
	exit
fi

# folder sync support
if [ -e "sync.sh" ]; then
	source ./sync.sh
fi

# optional: copy the downloaded images into the Kindle's own screensaver folder
if [ -e "system.sh" ]; then
	source ./system.sh
fi

# fetch the screensaver(s); sets FETCH_CHANGED (0 = nothing new to show)
fetch_screensavers () {
	FETCH_CHANGED=1
	if [ -n "$SYNC_BASE_URI" ]; then
		sync_folder || return 1
		FETCH_CHANGED=$SYNC_CHANGED
		return 0
	fi
	curl -kl "$IMAGE_URI" -o "$TMPFILE" && mv "$TMPFILE" "$SCREENSAVERFILE"
}

# do nothing if neither a sync folder nor a single image URL is set
if [ -z "$IMAGE_URI" ] && [ -z "$SYNC_BASE_URI" ]; then
	logger "No image URL has been set. Please edit config.sh."
	exit 0
fi

logger "update started (sync folder: ${SYNC_BASE_URI:-none}, folder: $SCREENSAVERFOLDER)"

# enable wireless if it is currently off
if [ 0 -eq `lipc-get-prop com.lab126.cmd wirelessEnable` ]; then
	logger "WiFi is off, turning it on now"
	lipc-set-prop com.lab126.cmd wirelessEnable 1
	DISABLE_WIFI=1
fi

# wait for network to be up
TIMER=${NETWORK_TIMEOUT}     # number of seconds to attempt a connection
CONNECTED=0                  # whether we are currently connected
while [ 0 -eq $CONNECTED ]; do
	# test whether we can ping outside; if ping is blocked, try the download address itself
	if /bin/ping -c 1 $TEST_DOMAIN > /dev/null 2>&1; then
		CONNECTED=1
	elif [ -n "$SYNC_BASE_URI" ] && curl -skf -m 5 -o /dev/null "$SYNC_META_URI"; then
		CONNECTED=1
	fi

	# if we can't, checkout timeout or sleep for 1s
	if [ 0 -eq $CONNECTED ]; then
		TIMER=$(($TIMER-1))
		if [ 0 -eq $TIMER ]; then
			logger "No internet connection after ${NETWORK_TIMEOUT} seconds, aborting."
			break
		else
			sleep 1
		fi
	fi
done

if [ 1 -eq $CONNECTED ]; then
	if fetch_screensavers; then
		logger "Screen saver image file(s) checked/updated"
		if [ "x$TARGET_MODE" = "xsystem" ] && [ -n "$SYNC_BASE_URI" ]; then
			apply_to_system || logger "system screensavers were not updated"
		fi
                # refresh screen (only when something changed)
                [ "$FETCH_CHANGED" -gt 0 ] && [ -f "$SCREENSAVERFILE" ] && lipc-get-prop com.lab126.powerd status | grep "Screen Saver" && (
                     logger "Updating image on screen"
                     eips -f -g $SCREENSAVERFILE
                     batt=`powerd_test -s | awk -F: '/Battery Level: / {print $2}' | awk -F' |%' '{print $2}'`
# Create json for POST
generate_post_data()
{
  cat<<EOF
{
  "kindle_battery":"$batt"
}
EOF
}
                     # If WEBHOOKADR has been defined, send data
					 if [ -n "$WEBHOOKADR" ]; then
                       curl -X POST -k -d "$(generate_post_data)" -H 'Content-Type: application/json' "$WEBHOOKADR"
                     fi
                     eips 40 39 "Batt:${batt}%"
                )
	else
		logger "Error updating screensaver"
		if [ 1 -eq $DONOTRETRY ]; then
			touch $SCREENSAVERFILE
		fi
	fi
fi

# disable wireless if necessary
if [ 1 -eq $DISABLE_WIFI ]; then
	logger "Disabling WiFi"
	lipc-set-prop com.lab126.cmd wirelessEnable 0
fi

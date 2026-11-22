#!/bin/sh
#
# Turn auto-download on/off and choose how often it checks.
#   set-hours.sh 12     check every 12 hours (turns auto-download on)
#   set-hours.sh 0      turn auto-download off
#   set-hours.sh        apply the AUTO_HOURS already in bin/auto.conf
# The value is saved in bin/auto.conf, which config.sh reads.

# change to directory of this script
cd "$(dirname "$0")"

# load utils (logger) and configuration
if [ -e "utils.sh" ]; then
	source ./utils.sh
else
	echo "Could not find utils.sh in `pwd`"
	exit 1
fi

if [ -n "$1" ]; then
	case "$1" in
		*[!0-9]*) echo "hours must be a whole number (0 = off)"; exit 1 ;;
	esac
	printf 'AUTO_HOURS=%s
' "$(expr "$1" + 0)" > auto.conf
fi

# config.sh reads auto.conf and validates the value
if [ -e "config.sh" ]; then
	source ./config.sh
fi

if [ "$AUTO_HOURS" -le 0 ]; then
	logger "auto-download: turned OFF"
	stop onlinescreensaver > /dev/null 2>&1
	sh ./disable.sh
	exit 0
fi

logger "auto-download: every $AUTO_HOURS hour(s)"
if [ -e /etc/upstart/onlinescreensaver.conf ]; then
	# already installed: restart the job so the scheduler picks up the new interval
	# (the job has no main process, so it must be stopped before it can be started again)
	stop onlinescreensaver > /dev/null 2>&1
	start onlinescreensaver > /dev/null 2>&1 || 		/bin/sh /mnt/base-us/extensions/onlinescreensaver/bin/scheduler.sh > /dev/null 2>&1 &
else
	sh ./enable.sh
fi

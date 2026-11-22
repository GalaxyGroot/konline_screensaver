#!/bin/sh
#
# KUAL: choose where downloaded images go.
#   set-target.sh system   after each download, copy them into the Kindle's own
#                          screensaver folder (a backup of the originals is made
#                          first; nothing is changed if the backup fails)
#   set-target.sh user     only download into SCREENSAVERFOLDER (default)
# The choice is saved in bin/target.conf, which config.sh reads.

cd "$(dirname "$0")"
source ./config.sh
source ./utils.sh
source ./system.sh

case "$1" in
	system)
		if ! backup_system; then
			sys_say "System mode NOT enabled (no backup)"
			exit 1
		fi
		printf 'TARGET_MODE=system\n' > target.conf
		sys_say "System mode ON. Run Update now to apply the images"
		;;
	user)
		printf 'TARGET_MODE=user\n' > target.conf
		sys_say "System mode OFF: images stay in $SCREENSAVERFOLDER"
		;;
	*)
		echo "usage: set-target.sh system|user"
		exit 1
		;;
esac

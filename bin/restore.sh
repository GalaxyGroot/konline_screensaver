#!/bin/sh
#
# KUAL: restore the original system screensavers and switch system mode off.

cd "$(dirname "$0")"
source ./config.sh
source ./utils.sh
source ./system.sh

if restore_system; then
	printf 'TARGET_MODE=user\n' > target.conf
	sys_say "System mode is now OFF: new downloads stay in $SCREENSAVERFOLDER"
fi

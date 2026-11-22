#!/bin/sh
#
# KUAL: back up the Kindle's original screensavers (only if no backup exists yet).
# "backup.sh force" replaces an existing backup - only do that while the system
# folder still holds the ORIGINAL files, never after applying downloaded images.

cd "$(dirname "$0")"
source ./config.sh
source ./utils.sh
source ./system.sh

backup_system "$1"

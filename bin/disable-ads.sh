#!/bin/sh
#
# KUAL: remove the Kindle's lock-screen ads (special-offers) and reboot.
# Based on the "Disable Ads" extension by Marek.
#
# What it does:
#   - deletes /var/local/adunits and puts a plain file there so the firmware cannot recreate the folder
#   - deletes /mnt/us/.assets (cached ad images)
#   - sets adunit.viewable=false in appreg.db
#   - reboots after 5 seconds
# Log: disable_ads.log in the extension folder.

cd "$(dirname "$0")/.."
LOG="$(pwd)/disable_ads.log"
exec >> "$LOG" 2>&1
echo "=== $(date) ==="

echo "Removing adunits folder"
rm -rf /var/local/adunits
touch /var/local/adunits

echo "Removing ad assets"
rm -rf /mnt/us/.assets

echo "Updating appreg.db"
sqlite3 /var/local/appreg.db 'update properties set value = "false" where name = "adunit.viewable";'

echo "Rebooting in 5 seconds"
sleep 5
reboot

#############################################################################
### ONLINE-SCREENSAVER CONFIGURATION SETTINGS
#############################################################################

# Interval in MINUTES in which to update the screensaver by default. This
# setting will only be used if no schedule (see below) fits. Note that if the
# update fails, the script is not updating again until INTERVAL minutes have
# passed again. So chose a good compromise between updating often (to make
# sure you always have the latest image) and rarely (to not waste battery).
DEFAULTINTERVAL=360   # replaced by AUTO_HOURS (bottom of this file) when that is set

# Schedule for updating the screensaver. Use checkschedule.sh to check whether
# the format is correctly understood. 
#
# The format is a space separated list of settings for different times of day:
#       SCHEDULE="setting1 setting2 setting3 etc"
# where each setting is of the format
#       STARTHOUR:STARTMINUTE-ENDHOUR:ENDMINUTE=INTERVAL
# where
#       STARTHOUR:STARTMINUTE is the time this setting starts taking effect
#       ENDHOUR:ENDMINUTE is the time this setting stops being active
#       INTERVAL is the interval in MINUTES in which to update the screensaver
#
# Time values must be in 24 hour format and not wrap over midnight.
# EXAMPLE: "00:00-06:00=480 06:00-18:00=15 18:00-24:00=30"
#          -> Between midnight and 6am, update every 4 hours
#          -> Between 6am and 6pm (18 o'clock), update every 15 minutes
#          -> Between 6pm and midnight, update every 30 minutes
#
# Use the checkschedule.sh script to verify that the setting is correct and
# which would be the active interval.
SCHEDULE="00:00-24:00=360"   # replaced by AUTO_HOURS (bottom of this file) when that is set

# URL of screensaver image. This really must be in the EXACT resolution of
# your Kindle's screen (e.g. 600x800 or 758x1024) and really must be PNG.
#IMAGE_URI="http://enter.the.domain/here/and/the/path/to/the/image.png"
IMAGE_URI=""

# this extension's own folder, normally /mnt/us/extensions/onlinescreensaver
EXT_DIR="$(cd .. && pwd)"

# folder the images are downloaded into: the extension's own "downloaded" folder.
# Nothing else uses it, so it only ever holds the current set. (With system mode
# on, the set is then copied from here into the Kindle's own screensaver folder.)
SCREENSAVERFOLDER="$EXT_DIR/downloaded/"

# In which file to store the downloaded image. Make sure this is a valid
# screensaver file. E.g. check the current screensaver folder to see what
# the first filename is, then just use this. THIS FILE WILL BE OVERWRITTEN!
SCREENSAVERFILE=$SCREENSAVERFOLDER/bg_ss00.png

# Whether to create log output (1) or not (0).
LOGGING=0

# Where to log to - either /dev/stderr for console output, or an absolute
# file path (beware that this may grow large over time!)
#LOGFILE=/dev/stderr
LOGFILE=/mnt/us/onlinescreensaver.log

# whether to disable WiFi after the script has finished (if WiFi was off
# when the script started, it will always turn it off)
DISABLE_WIFI=0

# Domain to ping to test network connectivity. Default should work, but in
# case some firewall blocks access, try a popular local website.
TEST_DOMAIN="www.baidu.com"

# How long (in seconds) to wait for an internet connection to be established
# (if you experience frequent timeouts when waking up from sleep, try to
# increase this value)
NETWORK_TIMEOUT=30



# FOLDER SYNC (downloads many images instead of one).
# Base address of a folder that contains meta.json and screensavers/bg_ssNN.png
# (the "sync" folder of the K7Wallpaper repository). When this is set,
# IMAGE_URI above is ignored. Leave empty to use the single-image mode.
SYNC_BASE_URI="https://pkw-images.daofa.workers.dev"
# If raw.githubusercontent.com is blocked or slow where you are, a CDN mirror of
# the same folder may work, e.g.:
#SYNC_BASE_URI="https://cdn.jsdelivr.net/gh/GalaxyGroot/K7Wallpaper@main/sync"
# (jsDelivr caches the branch for up to ~12 hours.)

# Which size of the daily pick to download. The site publishes the same 13 images
# in several sizes: screensavers/600x800/ and screensavers/1072x1448/. Use the
# size of your Kindle's screen (Paperwhite 3/4 and Kindle 11: 1072x1448; basic
# Kindle and Kindle Touch: 600x800). Empty = the old single-size layout
# (<site>/meta.json and <site>/screensavers/bg_ssNN.png).
SYNC_SIZE="1072x1448"
if [ -n "$SYNC_SIZE" ]; then
	SYNC_FILES_URI="$SYNC_BASE_URI/screensavers/$SYNC_SIZE"
	SYNC_META_URI="$SYNC_BASE_URI/screensavers/$SYNC_SIZE/meta.json"
else
	SYNC_FILES_URI="$SYNC_BASE_URI/screensavers"
	SYNC_META_URI="$SYNC_BASE_URI/meta.json"
fi

# 1 = also delete bg_ss??.png files in the download folder that are NOT in
# meta.json, so it holds exactly the current set (it is this extension's own
# folder, so that is safe). 0 = keep older files.
SYNC_DELETE_EXTRA=1

#############################################################################
# Advanced
#############################################################################

# the real-time clock to use (0, 1 or 2)
# Modified =1 for Kindle Touch
RTC=1

# the temporary file to download the screensaver image to
TMPFILE=/tmp/tmp.onlinescreensaver.png

# webhook address, used for example in Home Assistant to retrieve battery %
# i.e. WEBHOOKADR="<HomeAssistantURL>/api/webhook/kindle-battery-update-hook"
WEBHOOKADR=""

#############################################################################
# AUTO-DOWNLOAD  (OFF by default)
#############################################################################
# 0 = off: nothing runs in the background. Images are only fetched when you
#     tap "Update now" in KUAL.
# N = check for new images every N hours (1-168).
#
# Do not edit this line. Choose the hours in the KUAL menu (Online-Screensaver >
# Auto-download ...); that writes bin/auto.conf. For a custom value, create
# bin/auto.conf containing a single line such as   AUTO_HOURS=8
# and run "Auto-download: apply bin/auto.conf" in KUAL.
AUTO_HOURS=0
if [ -f ./auto.conf ]; then
	source ./auto.conf
fi
case "$AUTO_HOURS" in
	''|*[!0-9]*) AUTO_HOURS=0 ;;
	*) AUTO_HOURS=$(expr "$AUTO_HOURS" + 0) ;;   # "08" -> 8
esac
[ "$AUTO_HOURS" -gt 168 ] && AUTO_HOURS=168
if [ "$AUTO_HOURS" -gt 0 ]; then
	DEFAULTINTERVAL=$(( AUTO_HOURS * 60 ))
	SCHEDULE="00:00-24:00=$DEFAULTINTERVAL"
fi

#############################################################################
# SYSTEM SCREENSAVERS  (OFF by default)
#############################################################################
# user   = images are only downloaded into SCREENSAVERFOLDER (default).
# system = after each download the images are also copied into the Kindle's
#          own screensaver folder, so the normal sleep screen shows them.
#          A verified backup of the original files is made first; nothing is
#          written if that fails. KUAL: Online-Screensaver > System screensavers
#          (ON / OFF / Create backup / Restore backup). That writes bin/target.conf.
TARGET_MODE=user
if [ -f ./target.conf ]; then
	source ./target.conf
fi
case "$TARGET_MODE" in
	system) ;;
	*) TARGET_MODE=user ;;
esac

# the Kindle's own screensaver folder (read-only partition, made writable only briefly)
SYSTEM_SCREENSAVER_DIR=/usr/share/blanket/screensaver
# 1 = after applying a new set, delete older bg_ss??.png files in that folder that
# are not part of it, so only the downloaded set remains. 0 = leave them.
SYSTEM_DELETE_EXTRA=1

# where this extension keeps its backup of the original screensavers and its state
BACKUP_DIR="$EXT_DIR/backup_screensavers"
STATE_DIR="$EXT_DIR/state"

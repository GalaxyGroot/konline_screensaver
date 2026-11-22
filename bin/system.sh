#!/bin/sh
#
##############################################################################
# System screensavers: back up, apply and restore the Kindle's own screensaver
# folder (SYSTEM_SCREENSAVER_DIR, normally /usr/share/blanket/screensaver).
#
# Safety rules:
#   - nothing is written to the system folder unless a verified backup of the
#     ORIGINAL files exists (it is created automatically before the first write)
#   - the system partition is only made writable when a file really differs
#   - every file is written under a temporary name, MD5-checked, then renamed,
#     so a file is never left half-written
#   - the partition is always switched back to read-only afterwards
#   - an existing complete backup is never overwritten by accident
#
# Sourced after config.sh and utils.sh. Expects: SYSTEM_SCREENSAVER_DIR,
# SCREENSAVERFOLDER, STATE_DIR, BACKUP_DIR, SYSTEM_DELETE_EXTRA.
# All functions return 0 on success, 1 on failure.

sys_say () {
	logger "$1"
	echo "$1"
	if command -v eips > /dev/null 2>&1; then
		eips 1 38 "$1" > /dev/null 2>&1
	fi
}

sys_md5 () {
	md5sum "$1" 2> /dev/null | cut -d' ' -f1
}

##############################################################################
# backup_system [force]  - copy the original files to BACKUP_DIR (once)

backup_system () {
	if [ -f "$BACKUP_DIR/.complete" ] && [ "x$1" != "xforce" ]; then
		logger "backup: already exists, not overwritten"
		return 0
	fi
	if [ ! -d "$SYSTEM_SCREENSAVER_DIR" ]; then
		sys_say "Backup failed: $SYSTEM_SCREENSAVER_DIR not found"
		return 1
	fi

	BK_TMP="${BACKUP_DIR}.tmp"
	rm -rf "$BK_TMP"
	mkdir -p "$BK_TMP" || { sys_say "Backup failed: cannot create $BK_TMP"; return 1; }

	BK_N=0
	for BK_F in "$SYSTEM_SCREENSAVER_DIR"/*; do
		[ -f "$BK_F" ] || continue
		BK_B=$(basename "$BK_F")
		if ! cp -f "$BK_F" "$BK_TMP/$BK_B" || [ "$(sys_md5 "$BK_F")" != "$(sys_md5 "$BK_TMP/$BK_B")" ]; then
			sys_say "Backup failed while copying $BK_B"
			rm -rf "$BK_TMP"
			return 1
		fi
		BK_N=$((BK_N + 1))
	done

	if [ "$BK_N" -lt 1 ]; then
		sys_say "Backup failed: no files in $SYSTEM_SCREENSAVER_DIR"
		rm -rf "$BK_TMP"
		return 1
	fi

	# the new copy is complete and verified: only now replace an older backup
	rm -rf "$BACKUP_DIR"
	mv "$BK_TMP" "$BACKUP_DIR" || { sys_say "Backup failed: cannot finish"; return 1; }
	touch "$BACKUP_DIR/.complete"
	sys_say "Backup done: $BK_N file(s) saved"
	return 0
}

##############################################################################
# apply_to_system  - copy the downloaded set (STATE_DIR/last-set.txt) from
# SCREENSAVERFOLDER into the system folder

apply_to_system () {
	AP_LIST="$STATE_DIR/last-set.txt"

	if [ ! -d "$SYSTEM_SCREENSAVER_DIR" ]; then
		sys_say "System screensaver folder not found"
		return 1
	fi
	if [ ! -s "$AP_LIST" ]; then
		sys_say "No downloaded set to apply yet (run Update now first)"
		return 1
	fi

	AP_W=/tmp/onlinescreensaver.apply.$$
	rm -rf "$AP_W"
	mkdir -p "$AP_W" || return 1
	: > "$AP_W/todo"
	: > "$AP_W/stale"

	# which files differ? (the downloaded copies must still match meta.json)
	while read -r AP_NAME AP_SUM; do
		if [ ! -f "$SCREENSAVERFOLDER/$AP_NAME" ] || [ "$(sys_md5 "$SCREENSAVERFOLDER/$AP_NAME")" != "$AP_SUM" ]; then
			sys_say "Downloaded file $AP_NAME missing or damaged, system not changed"
			rm -rf "$AP_W"
			return 1
		fi
		if [ "$(sys_md5 "$SYSTEM_SCREENSAVER_DIR/$AP_NAME")" != "$AP_SUM" ]; then
			echo "$AP_NAME" >> "$AP_W/todo"
		fi
	done < "$AP_LIST"

	# old files of the same naming scheme that are not in the new set
	if [ "x1" = "x$SYSTEM_DELETE_EXTRA" ]; then
		for AP_F in "$SYSTEM_SCREENSAVER_DIR"/bg_ss[0-9][0-9].png; do
			[ -f "$AP_F" ] || continue
			AP_B=$(basename "$AP_F")
			grep -q "^$AP_B " "$AP_LIST" || echo "$AP_B" >> "$AP_W/stale"
		done
	fi

	if [ ! -s "$AP_W/todo" ] && [ ! -s "$AP_W/stale" ]; then
		logger "system screensavers already up to date"
		rm -rf "$AP_W"
		return 0
	fi

	# 1. never touch the system without a verified backup of the originals
	if ! backup_system; then
		sys_say "No backup, system screensavers NOT changed"
		rm -rf "$AP_W"
		return 1
	fi

	# 2. enough room on the system partition? (sizes in KB, generous margin)
	AP_NEED=0
	while read -r AP_NAME; do
		AP_SZ=$(wc -c < "$SCREENSAVERFOLDER/$AP_NAME" | tr -d ' ')
		AP_NEED=$((AP_NEED + AP_SZ / 1024 + 1))
	done < "$AP_W/todo"
	AP_FREE=$(df -k "$SYSTEM_SCREENSAVER_DIR" 2> /dev/null | awk 'NR==2 {print $4}')
	case "$AP_FREE" in ''|*[!0-9]*) AP_FREE=0 ;; esac
	if [ "$AP_FREE" -lt $((AP_NEED + 2048)) ]; then
		sys_say "Not enough free space on the system partition (${AP_FREE} KB free)"
		rm -rf "$AP_W"
		return 1
	fi

	# 3. write
	if ! mntroot rw > /dev/null 2>&1; then
		sys_say "Could not make the system partition writable"
		rm -rf "$AP_W"
		return 1
	fi
	trap 'mntroot ro > /dev/null 2>&1; exit 1' INT TERM HUP

	AP_FAIL=0
	while read -r AP_NAME; do
		AP_SUM=$(grep "^$AP_NAME " "$AP_LIST" | cut -d' ' -f2)
		if cp -f "$SCREENSAVERFOLDER/$AP_NAME" "$SYSTEM_SCREENSAVER_DIR/$AP_NAME.new" && \
		   [ "$(sys_md5 "$SYSTEM_SCREENSAVER_DIR/$AP_NAME.new")" = "$AP_SUM" ] && \
		   chmod 644 "$SYSTEM_SCREENSAVER_DIR/$AP_NAME.new" && \
		   mv -f "$SYSTEM_SCREENSAVER_DIR/$AP_NAME.new" "$SYSTEM_SCREENSAVER_DIR/$AP_NAME"; then
			:
		else
			rm -f "$SYSTEM_SCREENSAVER_DIR/$AP_NAME.new"
			sys_say "Failed to write $AP_NAME, stopped"
			AP_FAIL=1
			break
		fi
	done < "$AP_W/todo"

	if [ "$AP_FAIL" -eq 0 ]; then
		while read -r AP_NAME; do
			rm -f "$SYSTEM_SCREENSAVER_DIR/$AP_NAME"
		done < "$AP_W/stale"
	fi

	mntroot ro > /dev/null 2>&1
	trap - INT TERM HUP
	rm -rf "$AP_W"

	if [ "$AP_FAIL" -ne 0 ]; then
		sys_say "System update incomplete. Use Restore if the sleep screen looks wrong"
		return 1
	fi

	lipc-set-prop com.lab126.powerd refreshScreenSaver 1 > /dev/null 2>&1
	mkdir -p "$STATE_DIR" && touch "$STATE_DIR/applied"
	sys_say "System screensavers updated (restart the Kindle if the old ones still show)"
	return 0
}

##############################################################################
# restore_system  - put the original files back, remove the ones we added

restore_system () {
	if [ ! -f "$BACKUP_DIR/.complete" ]; then
		sys_say "No complete backup found, nothing restored"
		return 1
	fi
	RS_N=0
	for RS_F in "$BACKUP_DIR"/*; do
		[ -f "$RS_F" ] && RS_N=$((RS_N + 1))
	done
	if [ "$RS_N" -lt 1 ]; then
		sys_say "Backup folder is empty, nothing restored"
		return 1
	fi
	if ! mntroot rw > /dev/null 2>&1; then
		sys_say "Could not make the system partition writable"
		return 1
	fi
	trap 'mntroot ro > /dev/null 2>&1; exit 1' INT TERM HUP

	RS_FAIL=0
	# files that are not part of the original set go away
	for RS_F in "$SYSTEM_SCREENSAVER_DIR"/*.png; do
		[ -f "$RS_F" ] || continue
		RS_B=$(basename "$RS_F")
		[ -f "$BACKUP_DIR/$RS_B" ] || rm -f "$RS_F"
	done
	# put every original back
	for RS_F in "$BACKUP_DIR"/*; do
		[ -f "$RS_F" ] || continue
		RS_B=$(basename "$RS_F")
		if [ "$(sys_md5 "$RS_F")" = "$(sys_md5 "$SYSTEM_SCREENSAVER_DIR/$RS_B")" ]; then
			continue
		fi
		if cp -f "$RS_F" "$SYSTEM_SCREENSAVER_DIR/$RS_B.new" && \
		   [ "$(sys_md5 "$RS_F")" = "$(sys_md5 "$SYSTEM_SCREENSAVER_DIR/$RS_B.new")" ] && \
		   mv -f "$SYSTEM_SCREENSAVER_DIR/$RS_B.new" "$SYSTEM_SCREENSAVER_DIR/$RS_B"; then
			:
		else
			rm -f "$SYSTEM_SCREENSAVER_DIR/$RS_B.new"
			sys_say "Failed to restore $RS_B"
			RS_FAIL=1
		fi
	done

	mntroot ro > /dev/null 2>&1
	trap - INT TERM HUP

	if [ "$RS_FAIL" -ne 0 ]; then
		sys_say "Restore incomplete, run it again"
		return 1
	fi
	lipc-set-prop com.lab126.powerd refreshScreenSaver 1 > /dev/null 2>&1
	rm -f "$STATE_DIR/applied"
	sys_say "Original screensavers restored (restart the Kindle if needed)"
	return 0
}

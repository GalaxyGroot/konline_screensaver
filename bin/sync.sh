#!/bin/sh
#
##############################################################################
# Folder sync for the online screensaver.
#
# Downloads SYNC_META_URI (<site>/screensavers/<SYNC_SIZE>/meta.json), then every bg_ssNN.png it
# lists whose MD5 differs from the local file in $SCREENSAVERFOLDER.
#   - nothing is replaced unless ALL needed files downloaded and passed MD5,
#     so a failed run never leaves a half-updated set
#   - if SYNC_DELETE_EXTRA=1, local bg_ss??.png files NOT in meta.json are removed
#
# meta.json format: {"bg_ss00.png": "<md5>", "bg_ss01.png": "<md5>", ...}
# Expects logger() from utils.sh. Sets SYNC_CHANGED (files added/replaced/removed).
# Returns 0 on success (even if nothing changed), 1 on any failure.

SYNC_CHANGED=0

sync_folder () {
	SYNC_CHANGED=0
	SYNC_WORK=/tmp/onlinescreensaver.sync.$$
	rm -rf "$SYNC_WORK"
	mkdir -p "$SYNC_WORK" || return 1

	curl -skfL -m 60 "$SYNC_META_URI" -o "$SYNC_WORK/meta.json"
	SYNC_RC=$?
	if [ "$SYNC_RC" -ne 0 ]; then
		logger "sync: could not download $SYNC_META_URI (curl exit $SYNC_RC)"
		rm -rf "$SYNC_WORK"
		return 1
	fi

	# "name md5" per line; works for indented or single-line JSON
	tr -d '{}' < "$SYNC_WORK/meta.json" | tr ',' '\n' | \
		sed -n 's/^[^"]*"\(bg_ss[0-9][0-9]*\.png\)"[^"]*"\([0-9a-fA-F]\{32\}\)".*$/\1 \2/p' > "$SYNC_WORK/list"
	SYNC_N=$(wc -l < "$SYNC_WORK/list" | tr -d ' ')
	if [ "$SYNC_N" -lt 1 ]; then
		logger "sync: meta.json has no usable entries, keeping current screensavers"
		rm -rf "$SYNC_WORK"
		return 1
	fi

	mkdir -p "$SCREENSAVERFOLDER"
	SYNC_NEW=0
	SYNC_FAILED=0
	while read -r SYNC_NAME SYNC_SUM; do
		SYNC_CUR=""
		if [ -f "$SCREENSAVERFOLDER/$SYNC_NAME" ]; then
			SYNC_CUR=$(md5sum "$SCREENSAVERFOLDER/$SYNC_NAME" | cut -d' ' -f1)
		fi
		[ "$SYNC_CUR" = "$SYNC_SUM" ] && continue

		curl -skfL -m 120 "$SYNC_FILES_URI/$SYNC_NAME" -o "$SYNC_WORK/$SYNC_NAME"
		SYNC_RC=$?
		if [ "$SYNC_RC" -eq 0 ] && [ "$(md5sum "$SYNC_WORK/$SYNC_NAME" | cut -d' ' -f1)" = "$SYNC_SUM" ]; then
			SYNC_NEW=$((SYNC_NEW + 1))
		else
			logger "sync: download or MD5 check failed for $SYNC_NAME (curl exit $SYNC_RC)"
			rm -f "$SYNC_WORK/$SYNC_NAME"
			SYNC_FAILED=$((SYNC_FAILED + 1))
		fi
	done < "$SYNC_WORK/list"

	if [ "$SYNC_FAILED" -gt 0 ]; then
		logger "sync: $SYNC_FAILED file(s) failed, leaving $SCREENSAVERFOLDER untouched"
		rm -rf "$SYNC_WORK"
		return 1
	fi

	# all downloads verified: install them
	for SYNC_F in "$SYNC_WORK"/bg_ss*.png; do
		[ -f "$SYNC_F" ] || continue
		mv -f "$SYNC_F" "$SCREENSAVERFOLDER/" || { rm -rf "$SYNC_WORK"; return 1; }
	done
	SYNC_CHANGED=$SYNC_NEW

	if [ "x1" = "x$SYNC_DELETE_EXTRA" ]; then
		for SYNC_F in "$SCREENSAVERFOLDER"/bg_ss[0-9][0-9].png; do
			[ -f "$SYNC_F" ] || continue
			SYNC_B=$(basename "$SYNC_F")
			if ! grep -q "^$SYNC_B " "$SYNC_WORK/list"; then
				rm -f "$SYNC_F"
				SYNC_CHANGED=$((SYNC_CHANGED + 1))
			fi
		done
	fi

	# remember the verified set (name + MD5) for the optional system step
	if [ -n "$STATE_DIR" ]; then
		mkdir -p "$STATE_DIR" && cp -f "$SYNC_WORK/list" "$STATE_DIR/last-set.txt"
	fi

	logger "sync: done, $SYNC_NEW downloaded, $SYNC_CHANGED changed in total, $SYNC_N in meta.json"
	rm -rf "$SYNC_WORK"
	return 0
}

# konline_screensaver

A [KUAL](https://www.mobileread.com/forums/showthread.php?t=225030) extension for jailbroken Kindles that downloads fresh sleep-screen images from the internet, either on demand or on a schedule.

This is a fork of **Online Screensaver**, extended for **hard-float firmware** (for example 5.18.x) where the `linkss` screensaver hack cannot be installed. It can download a whole folder of images, keep it in sync, and optionally write it into the Kindle's own screensaver folder, with a backup made first.

> Use at your own risk. It is tested on a real Kindle only in part (see [Status](#status)). If something goes wrong, restarting the Kindle normally fixes it, and *Restore the original screensavers* undoes system mode.

## Credits

This project stands on other people's work. Please keep these credits if you fork it.

| Who | What |
|---|---|
| **peterson** ([MobileRead thread](https://www.mobileread.com/forums/showthread.php?t=236104)) | Wrote the original *Online Screensaver* extension (v0.3) and the scheduler/RTC wake-up logic. All the core ideas are theirs. |
| **GalaxyGroot** | This fork: folder sync, system screensaver mode with backup/restore, simple auto-download menu. |

Thanks to the Kindle developer community on MobileRead.

## What you need

1. A **jailbroken Kindle** with [KUAL](https://www.mobileread.com/forums/showthread.php?t=225030) v2 or later installed.
2. Wi-Fi.
3. Images in your screen's exact size, as **8-bit PNG** with no colour profile:

| Kindle | Size |
|---|---|
| Basic Kindle (7th gen / KT3), Kindle Touch | 600x800 |
| Paperwhite 1/2 | 758x1024 |
| Paperwhite 3/4/5, Kindle 11 and later | 1072x1448 |

You can test an image on the Kindle with `eips -f -g image.png`. A white screen means the PNG is not clean.

## Quick start (about 5 minutes)

1. **Download** this repository (green *Code* button, then *Download ZIP*) and unzip it.
2. **Rename** the unzipped folder to `onlinescreensaver` and copy it to the `extensions` folder of the Kindle, so you end up with `/mnt/us/extensions/onlinescreensaver/` (the file `menu.json` must be directly inside).
3. **Choose your screen size.** Open `bin/config.sh` in an editor that keeps Unix (LF) line endings, such as Notepad++ or VS Code (not Windows Notepad), and set `SYNC_SIZE`:
   ```sh
   SYNC_SIZE="1072x1448"   # or "600x800" for a basic Kindle / Kindle Touch
   ```
4. If you cannot reach the default server, change `SYNC_BASE_URI` (a mirror example is in the file) and `TEST_DOMAIN`.
5. Eject the Kindle. Open **KUAL > Online-Screensaver > Update now**. The images are downloaded to `/mnt/us/extensions/onlinescreensaver/downloaded/`.
6. **Show them.** Pick one route (next section).

## Make the images appear on the sleep screen

The default mode only downloads files and changes nothing else. Pick what suits your Kindle:

**A. KOReader (safest, nothing on the system changes).** In KOReader set the sleep-screen image folder to `/mnt/us/extensions/onlinescreensaver/downloaded/`.

**B. Kindle's own sleep screen (system mode).** KUAL > Online-Screensaver > **System screensavers > ON: back up originals, then apply downloads**, then tap **Update now**. It:
- makes a verified backup of your original screensavers in `extensions/onlinescreensaver/backup_screensavers/` (if that fails, nothing is changed, and an existing complete backup is never overwritten),
- then copies the downloaded set into `/usr/share/blanket/screensaver`.

If the old images still show, restart the Kindle. To go back: **System screensavers > Restore the original screensavers**. A firmware update can overwrite the system folder; just run *Update now* again (or *Restore*).

## Keep it up to date automatically

Auto-download is **off by default**, so nothing runs in the background and no battery is used.

KUAL > Online-Screensaver > **Auto-download**:
- **OFF (default)**
- **Every 24 hours** (enough, since the image set changes once a day)
- **Apply bin/auto.conf (custom hours)**: create `bin/auto.conf` containing `AUTO_HOURS=8` (1 to 168), then run this entry.

The first time you pick an interval, a startup file is installed into `/etc/upstart` (this uses `mntroot rw` briefly). The Kindle wakes briefly at each interval to download, which costs some battery. It does not work if the Kindle was fully powered off.

## KUAL menu

| Entry | What it does |
|---|---|
| Update now | Download new images once. |
| System screensavers > ON | Back up the originals, switch system mode on. Run *Update now* to apply. |
| System screensavers > Restore | Put the originals back, remove the added files, switch system mode off. |
| Auto-download > OFF / Every 24 hours / Apply bin/auto.conf | Schedule control. |

## Settings (`bin/config.sh`)

| Setting | Meaning |
|---|---|
| `SYNC_BASE_URI` | Server folder that holds `meta.json` and the images. When set, `IMAGE_URI` is ignored. |
| `SYNC_SIZE` | `1072x1448` or `600x800` (see the table above). |
| `SYNC_DELETE_EXTRA` | `1` (default) removes `bg_ss??.png` files that are not in `meta.json`. |
| `IMAGE_URI` | URL of one PNG, used only if `SYNC_BASE_URI` is empty. |
| `TEST_DOMAIN` | Host pinged to detect a connection (default `www.baidu.com`). |
| `NETWORK_TIMEOUT` | Seconds to wait for Wi-Fi (raise it if wake-ups time out). |
| `DISABLE_WIFI` | `1` turns Wi-Fi off after the run. |
| `LOGGING` / `LOGFILE` | Set `LOGGING=1` to log to `/mnt/us/onlinescreensaver.log`. |
| `RTC` | Real-time clock used to wake the Kindle (0, 1 or 2; `1` for Kindle Touch). |
| `WEBHOOKADR` | Optional: send the battery level to Home Assistant (see below). |
| `TARGET_MODE` | `user` (default) or `system`. Set by the menu, in `bin/target.conf`. |
| `AUTO_HOURS` | Set by the menu, in `bin/auto.conf`. Do not edit it in `config.sh`. |

Always edit with Unix (LF) line endings, and keep the scripts as POSIX `sh`.

## How folder sync works

`bin/sync.sh` downloads `<SYNC_BASE_URI>/screensavers/<SYNC_SIZE>/meta.json`, then every `bg_ssNN.png` it lists whose MD5 differs from the local copy in `downloaded/`. Nothing is replaced unless all needed files downloaded and passed the MD5 check, so a failed run never leaves a half-updated set. The screen is refreshed only when something changed.

The default server publishes a daily pick of 13 images from the [K7Wallpaper](https://github.com/GalaxyGroot/K7Wallpaper) repository, in both sizes.

## Safety rules of system mode (`bin/system.sh`)

- No write without a verified backup.
- The system partition is made writable (`mntroot rw`) only when a file really differs, and is always set back to read-only.
- Every file is written under a temporary name, MD5-checked, then renamed.
- Free space is checked first, and the downloaded files must still match `meta.json`.
- `SYSTEM_DELETE_EXTRA=1` (default) removes older `bg_ss??.png` files that are not part of the new set.

## Status

Folder sync and system mode were tested against a local HTTP server and scratch folders with stubbed Kindle commands, and the basic download flow on a real Kindle. System mode has **not** been verified on a device yet. Please report your results by opening an issue.

## Troubleshooting

| Problem | Try |
|---|---|
| White or wrong-sized screen | Check size, 8-bit grayscale PNG, no ICC profile; test with `eips -f -g image.png`. |
| "Update now" does nothing | Set `LOGGING=1`, run again, read `/mnt/us/onlinescreensaver.log`. Check `TEST_DOMAIN` and `SYNC_BASE_URI` are reachable from your network. |
| Menu entry missing or script fails | Line endings were changed to CRLF. Re-save the files with LF endings. |
| Old images still show after system mode | Restart the Kindle. |
| Want the original screens back | *System screensavers > Restore the original screensavers*. |

## Optional: Home Assistant battery webhook

Set `WEBHOOKADR` in `bin/config.sh`, for example `WEBHOOKADR="<HomeAssistantURL>/api/webhook/kindle-battery-update-hook"`. In Home Assistant `configuration.yaml`:

```yaml
template:
  - trigger:
    - platform: webhook
      webhook_id: kindle-battery-update-hook # as used in config.sh
    sensor:
    - name: "Kindle Battery"
      state: '{{ trigger.json[''kindle_battery''] }}'
```

## Uninstall

1. KUAL > Online-Screensaver > System screensavers > **Restore the original screensavers** (if you used system mode).
2. KUAL > Online-Screensaver > Auto-download > **OFF**.
3. Delete `/mnt/us/extensions/onlinescreensaver/`.

## License

MIT. See [LICENSE](LICENSE).

Discussion of the original extension: <https://www.mobileread.com/forums/showthread.php?t=236104>

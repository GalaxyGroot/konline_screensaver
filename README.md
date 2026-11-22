## System screensavers: back up, apply, restore (added for hard-float Kindles)

`linkss` cannot be installed on hard-float firmware, so this copy can also put the downloaded images **into the Kindle's own screensaver folder**, `/usr/share/blanket/screensaver`, where the normal sleep screen reads them. It is OFF by default (`TARGET_MODE=user`: images only go to the extension's own `downloaded` folder).

KUAL: *Online-Screensaver > System screensavers*
- *ON: back up originals, then apply downloads* - makes a verified backup of the original files in `extensions/onlinescreensaver/backup_screensavers/` (nothing is enabled if that fails; an existing complete backup is never overwritten), then turns system mode on. Run *Update now* to apply.
- *Restore the original screensavers* - puts the original files back, removes the ones that were added, and switches system mode off.

(`bin/set-target.sh user` and `bin/backup.sh` still exist for manual use but are not in the menu: *ON* already makes the backup, and *Restore* already switches system mode off.)

Safety rules in `bin/system.sh`: no write without a verified backup; the system partition is made writable (`mntroot rw`) only when a file really differs, and always set back to read-only; every file is written under a temporary name, MD5-checked, then renamed; free space is checked first; downloaded files must still match `meta.json`; `SYSTEM_DELETE_EXTRA=1` (default) removes older `bg_ss??.png` files that are not part of the new set. After a change the script asks the Kindle to refresh (`refreshScreenSaver`); restart the Kindle if the old images still show. A firmware update can overwrite the system folder (use *Restore*/*Update now* again). Tested only against scratch folders with stubbed Kindle commands, not on a device.

## Folder sync (added for the Kindle 7 + K7Wallpaper repo)

Besides a single image, this copy can keep a whole folder of screensavers up to date:

- `bin/sync.sh` downloads `<site>/screensavers/<SYNC_SIZE>/meta.json` (`SYNC_SIZE` in `bin/config.sh`: `1072x1448` for a Paperwhite 3/4 or Kindle 11, `600x800` for a basic Kindle), then every `bg_ssNN.png` in that folder it lists whose MD5 differs from the local file in its own folder `onlinescreensaver/downloaded/` (`SCREENSAVERFOLDER`).
- Nothing is replaced unless all needed files downloaded and passed the MD5 check, so a failed run never leaves a half-updated set.
- Set `SYNC_BASE_URI` in `bin/config.sh` (already pointing at `GalaxyGroot/K7Wallpaper`, `main/sync`). When it is set, `IMAGE_URI` is ignored. `SYNC_DELETE_EXTRA=1` also removes `bg_ss??.png` files that are not in `meta.json`.
- **Auto-download is OFF by default**: nothing runs in the background and images are only fetched when you tap *Update now*. To turn it on, choose *Auto-download: every 24 hours* in KUAL (or a custom number of hours through `bin/auto.conf`) (the GitHub Action publishes a new pick every 24 hours, so once a day is enough). *Auto-download: OFF* turns it off again. For another number of hours, create `bin/auto.conf` containing `AUTO_HOURS=8` (1-168) and run *Auto-download: apply bin/auto.conf*. The choice is stored in `bin/auto.conf`; `scheduler.sh` refuses to run while it is 0, so a scheduler installed earlier also stays off after a reboot.
- `TEST_DOMAIN` is the host pinged to detect a connection; the default is `www.baidu.com`, change it if that is not reachable for you.
- The screen is only refreshed when something actually changed. In system mode the Kindle may need a restart before the stock sleep screen uses the new files.
- Install: copy this folder to `/mnt/us/extensions/onlinescreensaver/` on the Kindle, then use KUAL: *Online-Screensaver > Update now*, or one of the *Auto-download* entries (the first time you pick an interval it installs a startup file into `/etc/upstart`, which needs `mntroot rw`).

Info
----
Original README below. I've just made few modifications to adapt what found here:  
https://www.mobileread.com/forums/showthread.php?t=236104  
to have it running in my old Kindle Touch.
In particular:
- Changed RTC=**1** in utils.sh
- Changed SCREENSAVERFILE=$SCREENSAVERFOLDER/**bg_xsmall_ss00**.png
- Included some changes proposed in the thread
- Added webhook to have the battery status in Home Assistant, described below  

I'm using this hack in combination with: https://github.com/sibbl/hass-lovelace-kindle-screensaver


Online Screensaver
------------------ 
v0.3
by peterson, via mobileread.com
thanks to the great folks in the Kindle developer corner

The Online Screensaver automatically fetches a new screensaver image from a
user-specified URL at a user-specified interval. If a screensaver is shown
at download time, the downloaded image will be displayed.

This extension supports updating the screensaver even when the Kindle is 
asleep (obviously it won't work if you have really powered the Kindle down
by pressing the power button for many seconds). As such, it will use 
additional battery as it will un-suspend your Kindle at the configured
intervals for one or two minutes.

The image should be in the correct resolution of your device, otherwise the
results may not look so pretty :-) The image also needs to be a "clean" png,
as otherwise you may only get a white screen (you can test whether an image
is working by calling "eips -f -g image.png" on your Kindle).

Possible use cases:
 - download the latest weather report (this was the initial reason this
   extension was developed), you need a server to automatically create this
   image - see for example https://github.com/mpetroff/kindle-weather-display
 - download the latest comic each day as your screensaver
 - download inspirational images/messages each day
 - etc


Disclaimer
----------

As of version 0.3, this extension has only been tested on a Kindle
Paperwhite 2 with WiFi. The auto-update script is currently only enabled
for devices with firmware 5 or newer (which should cover the devices that
actually have a front light).

If you get this extension to run on your device, please provide feedback
at http://www.mobileread.com/forums/showthread.php?t=236104 where you will
also find the latest version.

How this script interacts with 3G models is also unknown.

It is recommended to test the extension manually prior to activating auto
updates. To do so, connect to your Kindle via SSH (ref. USBNet) and run

	/mnt/us/extensions/onlinescreensaver/bin/scheduler.sh &

and then exit. If anything should go wrong, rebooting the Kindle should fix
any problem.

Either way, as usual please be advised that you are using this extension on
your own risk. 


Prerequisites
-------------

* You must have KUAL v2 or later installed.
* The linkss hack is NOT needed (it cannot be installed on hard-float firmware).
* By default, the extension downloads the images into its own folder,
  /mnt/us/extensions/onlinescreensaver/downloaded, and touches nothing else.
  To make the Kindle's normal sleep screen use them, turn on KUAL >
  Online-Screensaver > System screensavers > ON (see the section at the top;
  a backup of the originals is made first).


Installation
------------

Unzip the downloaded file into the extensions folder (/mnt/us/extensions
when using SSH, otherwise the extensions folder at root of the Kindle volume
when connected to your PC).


Configuration
-------------

Edit onlinescreensaver/bin/config.sh, all available options are described
here. Note that you MUST use an editor that supports Unix line endings. On
Windows, use e.g. the free notepad++ application.

**EDIT**: Variable WEBHOOKADR sets the possibility to send battery status as json via curl.
In Home Assistant set the following in configuration.yaml:
```
template:
  - trigger:
    - platform: webhook
      webhook_id: kindle-battery-update-hook # Or whatever you prefer, as defined in config.sh
    sensor:
    - name: "Kindle Battery"
      state: '{{ trigger.json[''kindle_battery''] }}'
```

Use
---

Run KUAL and enter the "Online-Screensaver" section. Here you have an item
to update the screensaver right away (one time), and you can also enable or
disable the auto-download.


Uninstalling
------------

It is recommended to disable auto-updates prior to deleting the folder
from the extensions directory.

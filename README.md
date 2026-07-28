# ls-rpi5labwc
## Shell scripts and setup for using Raspberry Pi 5 as LoopSign player

The starting point of the setup is a Raspberry Pi 5 running on Raspberry Pi OS Debian 12 (Bookworm) with desktop, using Labwc Wayland compositor. Release date: May 13 2025. Download [here](https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64.img.xz).

![LoopSign logo](LoopSign-logo.png)

## Concept

The purpose of the setup is to make the Raspberry Pi work as an unattended LoopSign player. Its main job is to launch the user's LoopSign screen, a static URL, in a fullscreen Chromium window. A set of bash scripts are part of this setup to make the Pi behave as intended and stably over time.

`autorun.sh` runs at boot, as defined in `~/.config/labwc/autostart`, and performs the following tasks in order:

1. Restarts udevmon to force-hide the cursor (utilizing separate repository [hideaway.git](https://github.com/Loop24-AS/hideaway)).
2. Waits for the system to get a working internet connection by checking if the player's date and time have synced with NTP.
3. Pulls this repository for changes and implements any updates. If there are updates to `autorun.sh`, the script restarts using the new version of itself.
4. Runs `define-sudo-crontab.sh` to install the root crontab (daily reboot).
5. Runs `hashgenerator.sh` to generate a unique seven-character code. The code is based on the Pi's ethernet MAC address, and it will always stay static for every specific Raspberry Pi if the script is re-run.
6. Runs `configure-kanshi.sh` to seed the display configuration if it is missing.
7. Starts `autorefresh.sh`, which refreshes Chromium every six hours and also acts as an internet connectivity watchdog.
8. Starts `cache-refresh.sh`, which performs a one-off hard refresh when a new cache-refresh flag has been committed to the repo.
9. Starts `configure-unattended-upgrades.sh` and `unattended-upgrades-time.sh` to install and configure automatic security updates.
10. Runs `loopsign.sh` to launch Chromium in fullscreen with the LoopSign URL. The hash code from step 5 is a unique part of the URL, making it easy for the user to pair the player to their corresponding LoopSign screen without needing to connect to the player and control its settings.
11. Starts `hideaway-trigger.sh`, which restarts udevmon again once a display has actually been detected.

It usually takes less than a minute from the desktop environment is loaded until Chromium is launched. Throughout the boot/startup process, the user is kept somewhat informed via different Zenity dialogs.

---

## Repository contents

| File | Purpose |
| --- | --- |
| `autorun.sh` | Master startup script. Self-updating; launches everything else. |
| `loopsign.sh` | Launches Chromium in kiosk mode with a custom user agent. |
| `autorefresh.sh` | Six-hour refresh loop + internet connectivity watchdog. |
| `cache-refresh.sh` | One-off hard refresh, triggered by `cache-refresh-flag`. |
| `cache-refresh-flag` | Date stamp. Change it to trigger a hard refresh fleet-wide. |
| `hashgenerator.sh` | Derives the static seven-character player code from the MAC address. |
| `configure-kanshi.sh` | Seeds `~/.config/kanshi/config` from `kanshi-config` if missing. |
| `kanshi-config` | Master display profile (1920x1080@60 on HDMI-A-1 / HDMI-A-2). |
| `define-sudo-crontab.sh` | Installs the root crontab from `sudo-crontab.txt`. |
| `sudo-crontab.txt` | Root crontab contents (daily 06:00 reboot via `safe-reboot.sh`). |
| `safe-reboot.sh` | Waits for any in-progress apt upgrade, then reboots. |
| `configure-unattended-upgrades.sh` | Installs and configures `unattended-upgrades`. |
| `20auto-upgrades` | Deployed to `/etc/apt/apt.conf.d/` — enables the periodic apt jobs. |
| `50unattended-upgrades` | Deployed to `/etc/apt/apt.conf.d/` — origins, cleanup, reboot policy. |
| `unattended-upgrades-time.sh` | Pins `apt-daily-upgrade.timer` to a fixed schedule. |
| `hideaway-trigger.sh` | Restarts udevmon once a display is detected, to re-hide the cursor. |
| `hidecursor.sh` | One-time provisioning: builds and installs HideAway. |
| `loopsignsplash.sh` | One-time provisioning: installs the LoopSign Plymouth boot splash. |
| `pishrink.sh` | Third-party tool ([PiShrink](https://github.com/Drewsif/PiShrink)) for shrinking exported images. |
| `splash.png`, `Linux background.png`, `LoopSign-logo.png` | Image assets. |

---

## Runtime scripts

### autorun.sh

Launched at login from `~/.config/labwc/autostart`. Logs to `/tmp/autorun.log` (overwritten each boot).

Two behaviours worth knowing about:

- **Branch selection.** The branch to pull is read from `/home/loopsign/config`. If the file does not exist it is created containing `prod`. Put `staging` in this file to point a single player at the staging branch for testing.
- **Self-update.** After pulling, `autorun.sh` compares the SHA-256 of the repo copy against the running copy at `/home/loopsign/autorun.sh`. If they differ, it writes a small helper script that moves the new version into place and re-executes it, then exits. This means a change to `autorun.sh` takes effect on the same boot it is pulled.

The repo is updated with `git fetch` followed by `git reset --hard origin/$BRANCH`, so any local modification inside `~/ls-rpi5labwc` is discarded on every boot.

### loopsign.sh

Launches Chromium in kiosk mode at `https://play.loopsign.eu/hash/<HASH>`, reading the hash from `/home/loopsign/Desktop/.hash.txt`. Logs to `/home/loopsign/loopsign.log`.

Before launching it builds a custom user agent so the player identifies itself to LoopSign, in the form:

```
Mozilla/5.0 (...) Chrome/<version> Safari/537.36 LoopSignPlayer/<Rpi5|Rpi4|UnknownPi>-2025.5:<display name>_<physical size>_<resolution>@<refresh rate>
```

Display details come from `wlr-randr` and the hardware model from `/proc/device-tree/model`. Each field falls back to a placeholder if it cannot be determined, so an odd display never blocks startup.

It also clears Chromium's `Singleton*` lock files and rewrites `exited_cleanly` / `exit_type` in the Chromium preferences, so an unclean shutdown (for example a power cut) never produces a "Restore pages?" prompt on the screen.

### autorefresh.sh

Runs two loops in parallel and logs to `/home/loopsign/autorefresh.log`.

- **Six-hour refresh loop** — if Chromium is running, sends `Ctrl+R` via `wtype` every six hours.
- **Connectivity watchdog** — polls `https://play.loopsign.eu/` with `curl`. While online it checks once a minute; once a check fails it switches to every three seconds. If the connection stays down for 60 seconds it shows a Zenity "Internet connection lost" warning. When connectivity returns, the warning is dismissed and Chromium is refreshed immediately.

### cache-refresh.sh

A mechanism for forcing a one-off hard refresh (`Ctrl+Shift+R`) across the fleet, for example after a LoopSign frontend deploy that would otherwise be masked by a stale cache.

It compares `cache-refresh-flag` in the repo against `/home/loopsign/cache-refresh-flag.done` on the device. If they differ, it waits five minutes (so the whole fleet does not hit the servers simultaneously at boot), performs the hard refresh, and writes the flag value to the done-file so it is not repeated.

**To trigger a refresh:** change the date in `cache-refresh-flag` and commit. Every player picks it up on its next boot.

### hashgenerator.sh

Reads the `eth0` MAC address, hashes it (SHA-256 → base64 → SHA-256), strips the visually ambiguous characters `1`, `I`, `O` and `0`, and writes the first seven characters uppercased to `/home/loopsign/Desktop/.hash.txt`. The result is stable for a given Pi across reboots and re-imaging.

### configure-kanshi.sh

Seeds `~/.config/kanshi/config` from the repo's `kanshi-config` **only if the target is missing or empty**, then restarts kanshi. An existing, non-empty config is left untouched — so a player that has been manually configured for a non-standard display keeps its settings.

### hideaway-trigger.sh

Polls `wlr-randr` every ten seconds until `HDMI-A-1` or `HDMI-A-2` appears, waits a further 60 seconds, then restarts udevmon. This re-triggers HideAway after the display has settled, covering the case where the cursor reappears because the monitor was connected or powered on late. Logs to `/home/loopsign/hideaway-trigger2.log`.

### define-sudo-crontab.sh

Installs `sudo-crontab.txt` as root's crontab, using the compare-and-deploy pattern used throughout this repo:

- Keeps a reference copy at `/home/loopsign/current-sudo-crontab.txt` and only reinstalls when the repo file differs from it.
- Backs the previous version up to `/tmp/sudo-crontab-backup-<timestamp>.txt` before overwriting.
- Skips everything if `/home/loopsign/manual-crontab.txt` exists, so an individual player can be given a hand-tuned crontab that survives repo updates.

---

## Automatic security updates

Security updates are applied unattended, in a fixed window, and coordinated with the daily reboot so an upgrade is never interrupted mid-flight.

Three pieces work together:

### 1. `configure-unattended-upgrades.sh`

Runs on every boot and is idempotent — after the first run it is just a couple of fast checks.

- Installs the `unattended-upgrades` package if `dpkg -s` shows it is missing.
- Deploys `20auto-upgrades` and `50unattended-upgrades` to `/etc/apt/apt.conf.d/`, using the same compare-and-deploy pattern as the crontab script: reference copies at `/home/loopsign/current-20auto-upgrades` and `/home/loopsign/current-50unattended-upgrades`, timestamped backups to `/tmp/` before overwriting, and no write at all when nothing has changed.
- Ensures `unattended-upgrades.service`, `apt-daily.timer` and `apt-daily-upgrade.timer` are enabled.
- Logs to `/home/loopsign/configure-unattended-upgrades.log`.

Creating `/home/loopsign/manual-unattended-upgrades-override.txt` on a device stops the apt configs from being redeployed there, for hand-tuning a single player.

### 2. `unattended-upgrades-time.sh`

Writes a systemd drop-in to `/etc/systemd/system/apt-daily-upgrade.timer.d/override.conf` that pins the upgrade run to a known moment instead of systemd's default randomised daily schedule:

```
[Timer]
OnCalendar=
OnCalendar=Sun *-*-* 05:57
RandomizedDelaySec=0
Persistent=true
```

The empty `OnCalendar=` clears the built-in schedule before the new one is set. `RandomizedDelaySec=0` removes the jitter systemd would otherwise add, and `Persistent=true` means a player that was switched off at the scheduled time runs the upgrade as soon as it is back on rather than skipping the week. The script only rewrites the override and restarts the timer when the content has actually changed.

**Note:** this is currently a *weekly* schedule (Sundays), carried over from the sibling [ls-x86intel](https://github.com/Loop24-AS/ls-x86intel) repository. Change the `OnCalendar` line to `*-*-* 05:57` for daily upgrades.

### 3. `safe-reboot.sh` and the daily reboot

`sudo-crontab.txt` reboots the player every day at 06:00 — but through `safe-reboot.sh` rather than calling `reboot` directly:

```
0 6 * * * /home/loopsign/ls-rpi5labwc/safe-reboot.sh
```

`safe-reboot.sh` polls `apt-daily-upgrade.service` every 30 seconds, for up to one hour, and only reboots once that service is no longer active. On the six days a week when no upgrade is scheduled the loop exits immediately and the reboot happens on time; on the upgrade day it waits for the run started at 05:57 to finish. If the hour times out it logs and gives up without rebooting. It logs to `/var/log/safe-reboot.log`.

Because reboots are handled this way, `50unattended-upgrades` sets `Unattended-Upgrade::Automatic-Reboot "false"` — unattended-upgrades must never reboot on its own schedule, or it would interrupt a screen during opening hours.

### What gets upgraded

`50unattended-upgrades` allows these origins:

```
"origin=Debian,codename=${distro_codename},label=Debian";
"origin=Debian,codename=${distro_codename},label=Debian-Security";
"origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
"origin=Raspberry Pi Foundation";
```

Both the standard Debian repositories and the Raspberry Pi Foundation repository (`archive.raspberrypi.com`) are needed — with only the Debian origins, Pi-specific packages such as the firmware and `raspi-config` would never be upgraded.

It also enables removal of unused kernels and dependencies, which matters on a 16 GB card, and leaves `Unattended-Upgrade::Package-Blacklist` empty.

### Verifying on a device

```
systemctl list-timers apt-daily-upgrade.timer
sudo unattended-upgrades --dry-run --debug
sudo crontab -l
cat /var/log/safe-reboot.log
tail /home/loopsign/configure-unattended-upgrades.log
```

---

## Configuration and state files

None of these live in the repo; they are created on the device.

| Path | Purpose |
| --- | --- |
| `/home/loopsign/config` | Branch to pull. Defaults to `prod`; set to `staging` for testing. |
| `/home/loopsign/Desktop/.hash.txt` | The player's seven-character pairing code. |
| `/home/loopsign/manual-crontab.txt` | If present, the root crontab is never redeployed. |
| `/home/loopsign/manual-unattended-upgrades-override.txt` | If present, the apt configs are never redeployed. |
| `/home/loopsign/current-sudo-crontab.txt` | Reference copy for crontab change detection. |
| `/home/loopsign/current-20auto-upgrades` | Reference copy for apt config change detection. |
| `/home/loopsign/current-50unattended-upgrades` | Reference copy for apt config change detection. |
| `/home/loopsign/cache-refresh-flag.done` | Last cache-refresh flag that was acted on. |

### Logs

| Path | Written by |
| --- | --- |
| `/tmp/autorun.log` | `autorun.sh` (and the stdout of everything it launches) |
| `/home/loopsign/loopsign.log` | `loopsign.sh` |
| `/home/loopsign/autorefresh.log` | `autorefresh.sh` |
| `/home/loopsign/hideaway-trigger2.log` | `hideaway-trigger.sh` |
| `/home/loopsign/configure-unattended-upgrades.log` | `configure-unattended-upgrades.sh` |
| `/var/log/safe-reboot.log` | `safe-reboot.sh` |
| `/var/log/unattended-upgrades/` | `unattended-upgrades` itself |

---

## Setup instructions

The Raspberry Pi OS image is burnt on a high speed 16 GB MicroSD card. Username: loopsign || Password: loop24

### Clone the ls-rpi5labwc repository

```
cd ~
git clone https://github.com/Loop24-AS/ls-rpi5labwc.git
```
Copy `autorun.sh` to `/home/loopsign/` and make it executable.
```
cp /home/loopsign/ls-rpi5labwc/autorun.sh /home/loopsign/autorun.sh
chmod +x /home/loopsign/autorun.sh
```

### Clone the hideaway repository and activate the plugin to hide the cursor
Make `hidecursor.sh` executable and run it.
```
chmod +x /home/loopsign/ls-rpi5labwc/hidecursor.sh
/home/loopsign/ls-rpi5labwc/hidecursor.sh
```

### Set autorun.sh to run at boot
Create `~/.config/labwc/autostart` and add command to run ~/autorun.sh at boot.
```
nano ~/.config/labwc/autostart
```
Add the following line.
```
/home/loopsign/autorun.sh &
```

### Install neccessary packages
```
sudo apt install fonts-noto-color-emoji wtype -y
```

`unattended-upgrades` is installed automatically by `configure-unattended-upgrades.sh` on first boot and does not need to be installed here. The scripts also rely on `zenity`, `curl`, `git`, `wlr-randr` and `kanshi`, which ship with the Raspberry Pi OS desktop image.

### Uninstall uneccessary packages
```
sudo apt remove geany -y && sudo apt autoremove -y
```

### Configure and set LoopSign Plymouth theme to enable LoopSign splash at boot
```
chmod +x ~/ls-rpi5labwc/loopsignsplash.sh
~/ls-rpi5labwc/loopsignsplash.sh
```

---

## Changes set in the GUI

### Raspberry Pi Configuration
Right-click ***Raspberry Configuration*** in the Raspberry Pi Menu and click ***Add to Desktop***. Right-click ***Screen Configuration*** in the Raspberry Pi Menu and click ***Add to Desktop***.

Double-click ***Raspberry Pi Configuration*** on the desktop. In the ***Display*** pane, make sure that ***Screen Blanking*** is disabled. In the ***Localisation*** pane, click ***Set Timezone*** and choose ***Area: Europe*** and ***Location: Oslo***; click ***Set Keyboard*** and choose ***Model: Logitech***, ***Layout: Norwegian*** and ***Variant: Norwegian***; click ***Set WLAN Country*** and choose ***NO Norway***.

Right-click the taskbar and choose ***Notifications***. Disable ***Show notifications***.

Remove the ***Updater*** icon from the taskbar.

### Chromium settings
Open Chromium and open URL `chrome://settings/cookies`. Enable ***Allow third-party cookies***. Open URL `chrome://settings/content/sound`. Add `https://play.loopsign.eu` and `https://edit.loopsign.eu` under ***Allowed to play sound***. Open `chrome://settings/languages`. Disable ***Spell check*** and ***Google Translate***. Open `chrome://settings/defaultBrowser` and click ***Make default***.

### Desktop
Right-click the desktop and open ***Desktop preferences***. Set `/home/loopsign/ls-rpi5labwc/Linux background.png` as desktop background picture. Disable ***Wastebasket***. Open the ***Taskbar*** pane and set ***Size: Medium (24x24)***, ***Position: Bottom***, ***Colour: Black*** and ***Text Colour: White***.

---

## Set up automatic root partition expansion after first boot

### Create the autoexpand shell script

Create and edit /root/autoexpand.sh:
```
sudo nano /root/autoexpand.sh
```

Paste the following, then save and exit:
```
#!/bin/bash
set -e

# Expand root partition using official raspi-config logic
raspi-config --expand-rootfs

# Disable this service for future boots and remove itself
systemctl disable autoexpand.service
rm -f /etc/systemd/system/autoexpand.service
systemctl daemon-reload
rm -f "$0"

# Reboot to complete expansion (raspi-config handles actual resize2fs on next boot)
reboot
```

Make the script executable:
```
sudo chmod +x /root/autoexpand.sh
```

### Create the systemd service file

Create and edit /etc/systemd/system/autoexpand.service:
```
sudo nano /etc/systemd/system/autoexpand.service
```

Paste the following, then save and exit:
```
[Unit]
Description=Auto-expand root partition on first boot (via raspi-config)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/root/autoexpand.sh

[Install]
WantedBy=multi-user.target
```

### Enable the systemd service

```
sudo systemctl enable autoexpand.service
```

### Clear machine-id to ensure first-boot script/services run

```
sudo rm -f /etc/machine-id
sudo touch /etc/machine-id
```

### Clear command history from terminal
```
history -c
> ~/.bash_history
```
Close terminal.

### Export image and shrink it
Insert USB memory stick and export image.
```
sudo dd if=/dev/mmcblk0 of=/media/loopsign/[name-of-memory-stick]/ls_image_2025_5_pi5.img bs=1M status=progress
```
Run pishrink.sh on the exported image to shrink and compress it.
```
sudo /home/loopsign/ls-rpi5labwc/pishrink.sh -s -z /media/loopsign/[name-of-memory-stick]/ls_image_2025_5_pi5.img
```
Eject the memory stick.

The image is now ready to be burnt onto an MicroSD card or USB memory stick to be used on a different Raspberry Pi 5.

---

## Development workflow

The repository has two long-lived branches:

- **`prod`** — what every player in the field runs.
- **`staging`** — for testing. Point a single player at it by writing `staging` into `/home/loopsign/config`, then reboot.

Because `autorun.sh` runs `git reset --hard origin/$BRANCH` on every boot, changes are deployed simply by pushing to the relevant branch — there is no separate release step. Two consequences worth keeping in mind:

- Never edit files inside `~/ls-rpi5labwc` on a player expecting them to persist; they are overwritten on the next boot. Use the manual-override files for genuinely device-specific configuration.
- A broken commit on `prod` reaches every player at their next boot. Test on `staging` first.

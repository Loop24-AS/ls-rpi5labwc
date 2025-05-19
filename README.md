# ls-rpi5labwc
## Shell scripts and setup for using Raspberry Pi 5 as LoopSign player

The starting point of the setup is a Raspberry Pi 5 running on Raspberry Pi OS Debian 12 (Bookworm) with desktop, using Labwc Wayland compositor. Release date: May 13 2025. Download [here](https://downloads.raspberrypi.com/raspios_arm64/images/raspios_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64.img.xz).

![LoopSign logo](LoopSign-logo.png)

## Concept
The purpose of the setup is to make the Raspberry Pi work as an unattended LoopSign player. Its main job is to launch the user's LoopSign screen, a static URL, in a fullscreen Chromium window. A set of bash scripts are part of this setup to make the Pi behave as intended and stably over time:
- `autorun.sh` will run at boot, as defined in `~/.config/labwc/autostart`. The script performs the following tasks in order:
  - Restarts udevmon to force-hide the cursor (utilizing separate repository [hideaway.git](https://github.com/Loop24-AS/hideaway)).
  - Waits for the system to get a working internet connection by checking if the player's date and time have synced with NTP.
  - Pulls this repository for changes and implements any updates. If there are updates to `autorun.sh`, the script restarts using the new version of itself.
  - Starts `autorefresh.sh` which will periodically (originally every three hours) do a refresh of Chromium if it's running.
  - Runs `generatehash.sh` to generate a unique seven-character code. The code is based on the Pi's ethernet MAC address, and it will always stay static for every specific Raspberry Pi if the script is re-run.
  - Runs `loopsign.sh` to launch Chromium in fullscreen with the LoopSign URL. The hash code from the previous step is a unique part of the URL, making it easy for the user to pair the player to their corresponding LoopSign screen without needing to connect to the player and control its settings.
- It usually takes less than a minute from the desktop environment is loaded until Chromium is launched.
- Throughout the boot/startup process, the user is kept somewhat informed via different Zenity dialogs.

## Setup instructions

The Raspberry Pi OS image is burnt on a high speed 16 GB MicroSD card. Username: loopsign || Password: loop24

### Clone the ls-rpi5 repository

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
Make `hidecursor.sh`executable and run it.
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

### Uninstall uneccessary packages
```
sudo apt remove geany -y && sudo apt autoremove -y
```
### Configure and set LoopSign Plymouth theme to enable LoopSign splash at boot
```
chmod +x ~/ls-rpi5labwc/loopsignsplash.sh
~/ls-rpi5labwc/loopsignsplash.sh
```

## Changes set in the GUI
### Raspberry Pi Configuration
Right-click ***Raspberry Configuration*** in the Raspberry Pi Menu and click ***Add to Desktop***. Right-click ***Screen Configuration*** in the Raspberry Pi Menu and click ***Add to Desktop***.

Double-click ***Raspberry Pi Configuration*** on the desktop. In the ***Display*** pane, make sure that ***Screen Blanking*** is disabled. In the ***Localisation*** pane, click ***Set Timezone*** and choose ***Area: Europe*** and ***Location: Oslo***; click ***Set Keyboard*** and choose ***Model: Logitech***, ***Layout: Norwegian*** and ***Variant: Norwegian***; click ***Set WLAN Country*** and choose ***NO Norway***.

Right-click the taskbar and choose ***Notifications***. Disable ***Show notifications***.

Remove the ***Updater*** icon from the taskbar.

### Chromium settings
Open Chromium and open URL `chrome://settings/cookies`. Enable ***Allow third-party cookies***. Open URL `chrome://settings/content/sound`. Add `https://play.loopsign.eu` and `https://edit.loopsign.eu` under ***Allowed to play sound***. Open `chrome://settings/languages`. Disable ***Spell check*** and ***Google Translate***. Open `chrome://settings/defaultBrowser` and click ***Make default***.

### Desktop
Right-click the desktop and open ***Desktop preferences***. Set `/home/loopsign/ls-rpi5/Linux background.png` as desktop background picture. Disable ***Wastebasket***. Open the ***Taskbar*** pane and set ***Size: Medium (24x24)***, ***Position: Bottom***, ***Colour: Black*** and ***Text Colour: White***.

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

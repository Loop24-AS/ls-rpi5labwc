#!/bin/bash

# Remove Singleton lock and session files to avoid issues with crash flags or that change of the Pi's username

rm -f \
  ~/.config/chromium/Singleton* \
#  ~/.config/chromium/Crashpad/completed \
#  ~/.config/chromium/Crashpad/pending/* \
#  ~/.config/chromium/Crashpad/attachments/* \
#  ~/.config/chromium/Default/Sessions/* \
#  ~/.config/chromium/Default/Current\ Session \
#  ~/.config/chromium/Default/Current\ Tabs \
#  ~/.config/chromium/Default/Last\ Session \
#  ~/.config/chromium/Default/Last\ Tabs

sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences

# Start Chromium in kiosk mode and navigate to LoopSign URL

# Read the hash from hash.txt on the Desktop
HASH=$(cat /home/loopsign/Desktop/.hash.txt)

# Launch Chromium in kiosk mode with the specified URL
# chromium-browser --disable-media-stream --start-maximized --start-fullscreen --disable-desktop-notifications --no-first-run https://play.loopsign.eu/hash/$HASH

chromium-browser --disable-media-stream --kiosk --disable-desktop-notifications --no-first-run https://play.loopsign.eu/hash/$HASH

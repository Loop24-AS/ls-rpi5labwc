#!/bin/bash

# CUSTOM BROWSER AGENT TAG

# ---- Detect Pi Hardware Model ----
MODEL=$(tr -d '\0' < /proc/device-tree/model)
if echo "$MODEL" | grep -q "Pi 5"; then
  HW="Rpi5"
elif echo "$MODEL" | grep -q "Pi 4"; then
  HW="Rpi4"
else
  HW="UnknownPi"
fi

# ---- Combine All in Custom Tag ----
TAG="LoopSignPlayer/${HW}-2025.5"

# ---- Get Chromium Version ----
CHROMIUM_VERSION=$(chromium --version | awk '{print $2}')

# ---- Default UA Prefix (truncated for clarity, update as needed) ----
DEFAULT_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${CHROMIUM_VERSION} Safari/537.36"

# ---- Final UA ----
FINAL_UA="$DEFAULT_UA $TAG"

# Remove Singleton lock and session files to avoid issues with crash flags or change of the Pi's username

rm -f \
  /home/loopsign/.config/chromium/Singleton* \

sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences

# Start Chromium in kiosk mode and navigate to LoopSign URL

# Read the hash from hash.txt on the Desktop
HASH=$(cat /home/loopsign/Desktop/.hash.txt)

# Launch Chromium in kiosk mode with the specified URL

chromium-browser --disable-gpu --disable-media-stream --kiosk --disable-desktop-notifications --no-first-run --user-agent="$FINAL_UA" https://play.loopsign.eu/hash/$HASH

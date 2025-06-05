#!/bin/bash

LOG_FILE="/home/loopsign/loopsign.log"

# --- Logging Function ---
log() {
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$TIMESTAMP $1" | tee -a "$LOG_FILE"
}

log "Script started."

# --- Detect Raspberry Pi Model ---
MODEL=$(tr -d '\0' < /proc/device-tree/model)
if echo "$MODEL" | grep -q "Pi 5"; then
  HW="Rpi5"
elif echo "$MODEL" | grep -q "Pi 4"; then
  HW="Rpi4"
else
  HW="UnknownPi"
fi

# --- Get Chromium Version ---
CHROMIUM_VERSION=$(chromium --version | awk '{print $2}')

# --- Extract Display Information ---
WLR_OUTPUT=$(wlr-randr)

# Get display name like "Ancor Communications Inc VS278 G5LMQS033589 (HDMI-A-1)"
DISPLAY_LINE=$(echo "$WLR_OUTPUT" | grep -oP '^HDMI-A-1 "\K[^"]+')
ACTUAL_DISPLAY_NAME=$(echo "$DISPLAY_LINE" | sed -E 's/ \([^()]+\)$//')

# Get physical size (e.g. 600x340)
PHYSICAL_SIZE=$(echo "$WLR_OUTPUT" | grep -A1 "$ACTUAL_DISPLAY_NAME" | awk -F'[:)]' '/Physical size/ {gsub(" mm", "", $2); print $2; exit}' | xargs)

# Try to extract resolution/refresh rate from (preferred, current) first
RES_LINE=$(echo "$WLR_OUTPUT" | grep '(preferred, current)' | head -n1)

# If not found, fall back to just (current)
if [ -z "$RES_LINE" ]; then
  RES_LINE=$(echo "$WLR_OUTPUT" | grep '(current)' | head -n1)
fi

# Extract resolution and refresh rate from the chosen line
read ACTIVE_RES ACTIVE_HZ <<< $(echo "$RES_LINE" | awk '{print $1, $3}' | sed 's/[^0-9x. ]//g')

# Truncate refresh rate to integer
ACTIVE_HZ=$(printf "%.0f" "$ACTIVE_HZ")

# Fallbacks
ACTUAL_DISPLAY_NAME=${ACTUAL_DISPLAY_NAME:-UnknownDisplay}
PHYSICAL_SIZE=${PHYSICAL_SIZE:-0x0}
ACTIVE_RES=${ACTIVE_RES:-0x0}
ACTIVE_HZ=${ACTIVE_HZ:-0}

# --- Construct Custom UA Tag ---
TAG="LoopSignPlayer/${HW}-2025.5:${ACTUAL_DISPLAY_NAME// /_}_${PHYSICAL_SIZE}_${ACTIVE_RES}@${ACTIVE_HZ}"

# --- Compose Final UA ---
DEFAULT_UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${CHROMIUM_VERSION} Safari/537.36"
FINAL_UA="$DEFAULT_UA $TAG"

log "Final UA: $FINAL_UA"

# --- Cleanup Chromium Singleton Flags ---
rm -f /home/loopsign/.config/chromium/Singleton*

# --- Mark session as clean ---
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences

# --- Load HASH from file ---
HASH=$(cat /home/loopsign/Desktop/.hash.txt)

# --- Launch Chromium in Kiosk Mode ---
log "Launching Chromium..."
chromium-browser \
  --disable-gpu \
  --disable-media-stream \
  --kiosk \
  --disable-desktop-notifications \
  --no-first-run \
  --user-agent="$FINAL_UA" \
  "https://play.loopsign.eu/hash/$HASH"

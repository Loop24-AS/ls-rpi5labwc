#!/bin/bash

LOG_FILE="/home/loopsign/hideaway-trigger.log"

log() {
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$TIMESTAMP $1" | tee -a "$LOG_FILE"
}

log "Script started."

# Wait until HDMI-A-1 or HDMI-A-2 shows up in wlr-randr output
log "Waiting for HDMI-A-1 or HDMI-A-2 to be connected..."

while ! wlr-randr | grep -q '^HDMI-A-[12]'; do
    log "No HDMI-A-1 or HDMI-A-2 detected yet. Retrying in 10 seconds..."
    sleep 10
done

log "Display detected on HDMI-A-1 or HDMI-A-2. Checking if Chromium is running"

# Function to check if Chromium is running
check_chromium() {
    pgrep chromium > /dev/null
    return $?
}

# Function to refresh Chromium using wtype
refresh_chromium() {
    # Ensure the script runs in the Wayland session
    export WAYLAND_DISPLAY=$(echo $WAYLAND_DISPLAY)
    export XDG_RUNTIME_DIR=$(echo $XDG_RUNTIME_DIR)
    wtype -M ctrl -k R -m ctrl
}

while true; do
    if check_chromium; then
        log "Chromium is running. Refreshing..."
        refresh_chromium
    else
        log "Chromium is not running."
    fi
    # Wait for 3 hours before repeating
    sleep 10800
done

#!/bin/bash

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
        echo "Chromium is running. Refreshing..."
        refresh_chromium
    else
        echo "Chromium is not running."
    fi
    # Wait for 3 hours before repeating
    sleep 10800
done

#!/bin/bash

# This script simulates pressing F24 after a physical display has been confirmed connected, checking every 30 seconds.
# This will trigger the cursor to hide (using HideAway) if a display with resolution higher than 1920x1080 is connected to the Pi after it has booted.

# Path to wtype binary
WTYPE_CMD="/usr/bin/wtype"

# Function to check if a real display is connected (i.e., not NOOP-1)
display_connected() {
    wlr-randr | grep -qE '^[A-Z]+-[0-9]+ connected' && \
    ! wlr-randr | grep -q "^NOOP-1"
}

echo "Waiting for real display connection..."

# Wait until a real display (non-NOOP) is detected
while ! display_connected; do
    sleep 30
done

echo "Display detected. Sending F24 to hide cursor..."
$WTYPE_CMD --delay 0 F24

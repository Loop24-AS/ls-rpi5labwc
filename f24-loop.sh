#!/bin/bash

# This script simulates pressing Ctrl after a physical display has been confirmed connected, checking every 30 seconds.
# This will trigger the cursor to hide (using HideAway) if a display with resolution higher than 1920x1080 is connected to the Pi after it has booted.

# Path to wtype binary
WTYPE_CMD="/usr/bin/wtype"

# Wait until HDMI-A-1 or HDMI-A-2 shows up in wlr-randr output
echo "Waiting for HDMI-A-1 or HDMI-A-2..."

while ! wlr-randr | grep -q '^HDMI-A-[12]'; do
    sleep 10
done

echo "Display detected on HDMI-A-1 or HDMI-A-2. Sending F24 to hide cursor..."
$WTYPE_CMD -M ctrl -m ctrl

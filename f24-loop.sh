#!/bin/bash

# This script simulates pressing F24 every 30 seconds using wtype.
# This will trigger the cursor to hide (using HideAway) if a display with resolution higher than 1920x1080 is connected to the Pi after it has booted.

while true; do
    /usr/bin/wtype --delay 0 F24
    sleep 30
done

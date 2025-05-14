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

log "Display detected on HDMI-A-1 or HDMI-A-2. Sending Ctrl+R with wtype to hide cursor..."
sleep 10
wtype -M ctrl -k R -m ctrl

log "Ctrl+R simulated. Script finished."

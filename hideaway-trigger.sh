#!/bin/bash

LOG_FILE="/home/loopsign/hideaway-trigger2.log"

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

log "Display detected on HDMI-A-1 or HDMI-A-2. Restarting udevmon to trigger HideAway after 30 seconds."

sleep 30
sudo systemctl restart udevmon

log "Udevmon restarted. Script finished."

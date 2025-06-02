#!/bin/bash

LOG_FILE="/home/loopsign/autorefresh.log"
CHECK_INTERVAL=10  # Check for reconnection every 10 seconds
LAST_CONNECTED=true

# --- Logging ---
log() {
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$TIMESTAMP $1" | tee -a "$LOG_FILE"
}

log "Script started."

# --- Chromium Check ---
check_chromium() {
    pgrep chromium > /dev/null
    return $?
}

# --- Refresh Chromium via wtype ---
refresh_chromium() {
    export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
    export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    wtype -M ctrl -k R -m ctrl
}

# --- Internet Check ---
is_connected() {
    ping -q -c1 -W1 8.8.8.8 &>/dev/null
}

# --- 3-hour refresh loop ---
three_hour_loop() {
    while true; do
        if check_chromium; then
            log "Chromium is running. Performing scheduled refresh..."
            refresh_chromium
        else
            log "Chromium is not running."
        fi
        log "Waiting 3 hours before next refresh."
        sleep 10800
    done
}

# --- Internet reconnection watchdog loop ---
watchdog_loop() {
    while true; do
        if is_connected; then
            if [[ "$LAST_CONNECTED" = false ]]; then
                log "Internet reconnected — refreshing Chromium."
                refresh_chromium
            fi
            LAST_CONNECTED=true
        else
            LAST_CONNECTED=false
        fi
        sleep "$CHECK_INTERVAL"
    done
}

# --- Run both loops in parallel ---
three_hour_loop &
watchdog_loop

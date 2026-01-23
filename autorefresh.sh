#!/bin/bash

LOG_FILE="/home/loopsign/autorefresh.log"
CHECK_INTERVAL=10  # Check every 10 seconds
DISCONNECT_NOTIFY_DELAY=60  # 1 minute
LAST_CONNECTED=true
ZENITY_PID=""

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
    curl -sf --max-time 3 https://www.google.com > /dev/null
}

# --- Zenity warning ---
show_disconnected_warning() {
    zenity --warning --text="Internet connection lost" --title="LoopSign" --timeout=0 &
    ZENITY_PID=$!
    log "Zenity warning shown. PID=$ZENITY_PID"
}

kill_zenity() {
    if [[ -n "$ZENITY_PID" ]] && kill -0 "$ZENITY_PID" 2>/dev/null; then
        kill "$ZENITY_PID"
        log "Zenity warning killed. PID=$ZENITY_PID"
        ZENITY_PID=""
    fi
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
    local disconnected_for=0
    while true; do
        if is_connected; then
            if [[ "$LAST_CONNECTED" = false ]]; then
                log "Internet reconnected — refreshing Chromium."
                kill_zenity
                refresh_chromium
            fi
            LAST_CONNECTED=true
            disconnected_for=0
        else
            if [[ "$LAST_CONNECTED" = true ]]; then
                log "Internet connection lost."
            fi
            LAST_CONNECTED=false
            ((disconnected_for+=CHECK_INTERVAL))
            if [[ "$disconnected_for" -ge "$DISCONNECT_NOTIFY_DELAY" ]] && [[ -z "$ZENITY_PID" ]]; then
                show_disconnected_warning
            fi
        fi
        sleep "$CHECK_INTERVAL"
    done
}

# --- Run both loops in parallel ---
three_hour_loop &
watchdog_loop

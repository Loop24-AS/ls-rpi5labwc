#!/bin/bash

LOG_FILE="/home/loopsign/autorefresh.log"
CHECK_INTERVAL_NORMAL=60
CHECK_INTERVAL_FAST=3
DISCONNECT_NOTIFY_DELAY=60
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
    curl -4 -sfI --connect-timeout 2 --max-time 6 https://play.loopsign.eu/ >/dev/null 2>&1
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

# --- 12-hour refresh loop ---
twelve_hour_loop() {
    while true; do
        if check_chromium; then
            log "Chromium is running. Performing scheduled refresh..."
            refresh_chromium
        else
            log "Chromium is not running."
        fi
        log "Waiting 12 hours before next refresh."
        sleep 43200
    done
}

# --- Internet reconnection watchdog loop ---
watchdog_loop() {
    local disconnect_start=0
    local in_grace_period=false

    while true; do
        if is_connected; then
            if [[ -n "$ZENITY_PID" ]]; then
                log "Internet reconnected — refreshing Chromium."
                kill_zenity
                refresh_chromium
            elif [[ "$in_grace_period" = true ]]; then
                log "Internet restored before warning threshold."
            fi

            LAST_CONNECTED=true
            in_grace_period=false
            disconnect_start=0

            sleep "$CHECK_INTERVAL_NORMAL"
        else
            if [[ "$LAST_CONNECTED" = true ]] && [[ "$in_grace_period" = false ]]; then
                log "Internet check failed. Entering grace period."
                LAST_CONNECTED=false
                in_grace_period=true
                disconnect_start=$(date +%s)
            fi

            if [[ "$in_grace_period" = true ]]; then
                local now
                now=$(date +%s)
                local offline_for=$((now - disconnect_start))

                if [[ "$offline_for" -ge "$DISCONNECT_NOTIFY_DELAY" ]] && [[ -z "$ZENITY_PID" ]]; then
                    log "Internet has been down for ${offline_for} seconds. Showing warning."
                    show_disconnected_warning
                    in_grace_period=false
                fi
            fi

            sleep "$CHECK_INTERVAL_FAST"
        fi
    done
}

# --- Run both loops in parallel ---
twelve_hour_loop &
watchdog_loop

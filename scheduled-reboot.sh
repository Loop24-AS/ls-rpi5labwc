#!/bin/bash

# Spread the daily reboot across a two-hour window instead of rebooting every
# player at the same moment. Cron (see sudo-crontab.txt) starts this script at
# WINDOW_START every day; the script then waits a player-specific delay before
# rebooting.
#
# The delay is derived from the eth0 MAC address, so a given player reboots at
# the same time every day. If the MAC address cannot be read, a random delay
# is used instead so the player still lands somewhere inside the window.
#
# Usage:
#   scheduled-reboot.sh          wait for the delay, then reboot
#   scheduled-reboot.sh --show   print the delay and reboot time without rebooting
#
# Logs: journalctl -t loopsign-reboot

WINDOW_START="04:00"   # must match the cron entry in sudo-crontab.txt
WINDOW_SECONDS=7200    # two hours
MAC_FILE="/sys/class/net/eth0/address"

MAC=$(cat "$MAC_FILE" 2>/dev/null | tr -d '[:space:]')

if [[ -n "$MAC" ]]; then
    # cksum gives a stable 32-bit integer for the MAC string.
    SEED=$(printf '%s' "$MAC" | cksum | awk '{print $1}')
    SOURCE="eth0 MAC $MAC"
else
    # Two RANDOM values combined to cover the full window evenly.
    SEED=$(( RANDOM * 32768 + RANDOM ))
    SOURCE="random (eth0 MAC not available)"
fi

DELAY=$(( SEED % WINDOW_SECONDS ))
WINDOW_START_EPOCH=$(date -d "today $WINDOW_START" +%s)
REBOOT_AT=$(date -d "@$(( WINDOW_START_EPOCH + DELAY ))" +%H:%M:%S)

if [[ "$1" == "--show" ]]; then
    echo "Seed source: $SOURCE"
    echo "Delay:       $DELAY seconds"
    echo "Reboot at:   $REBOOT_AT (cron starts the script at $WINDOW_START)"
    if [[ "$SOURCE" == random* ]]; then
        echo "Note:        random delay, will differ on every run"
    fi
    exit 0
fi

logger -t loopsign-reboot "Scheduled reboot in $DELAY seconds ($SOURCE), expected at $REBOOT_AT"
sleep "$DELAY"
logger -t loopsign-reboot "Performing scheduled reboot"
/usr/sbin/reboot

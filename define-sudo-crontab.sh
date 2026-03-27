#!/bin/bash

# Define paths
SOURCE_FILE="/home/loopsign/ls-rpi5labwc/sudo-crontab.txt"
CURRENT_FILE="/home/loopsign/current-sudo-crontab.txt"
MANUAL_OVERRIDE="/home/loopsign/manual-crontab.txt"

# If manual override file exists, do nothing
if [[ -f "$MANUAL_OVERRIDE" ]]; then
    echo "Manual crontab override detected ($MANUAL_OVERRIDE). Skipping installation."
    exit 0
fi

# Check if the source file exists
if [[ ! -f "$SOURCE_FILE" ]]; then
    echo "Error: Source file $SOURCE_FILE not found!"
    exit 1
fi

# Check if the current reference file exists
if [[ ! -f "$CURRENT_FILE" ]]; then
    echo "Current crontab reference not found, assuming first-time setup."
    sudo crontab < "$SOURCE_FILE"
    cp "$SOURCE_FILE" "$CURRENT_FILE"
    echo "Installed and stored new sudo crontab."
    exit 0
fi

# Compare the new file with the current reference
if cmp -s "$SOURCE_FILE" "$CURRENT_FILE"; then
    echo "No changes in sudo crontab. Nothing to update."
else
    BACKUP_FILE="/tmp/sudo-crontab-backup-$(date +%F_%T).txt"
    cp "$CURRENT_FILE" "$BACKUP_FILE"
    echo "Backup of previous sudo crontab saved to: $BACKUP_FILE"

    sudo crontab < "$SOURCE_FILE"
    cp "$SOURCE_FILE" "$CURRENT_FILE"
    echo "Updated sudo crontab and saved new reference."
fi

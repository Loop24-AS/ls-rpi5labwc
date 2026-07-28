#!/bin/bash

LOG_FILE="/home/loopsign/configure-unattended-upgrades.log"

log() {
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$TIMESTAMP $1" | tee -a "$LOG_FILE"
}

REPO_DIR="/home/loopsign/ls-rpi5labwc"
APT_CONF_DIR="/etc/apt/apt.conf.d"
MANUAL_OVERRIDE="/home/loopsign/manual-unattended-upgrades-override.txt"

log "Script started."

# --- Install the package if it's missing ---
if dpkg -s unattended-upgrades >/dev/null 2>&1; then
    log "unattended-upgrades is already installed."
else
    log "unattended-upgrades not found. Installing..."
    sudo apt-get update -qq
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades; then
        log "unattended-upgrades installed successfully."
    else
        log "ERROR: Failed to install unattended-upgrades. Exiting."
        exit 1
    fi
fi

# --- Deploy the two config files (unless manually overridden on this device) ---
if [[ -f "$MANUAL_OVERRIDE" ]]; then
    log "Manual override detected ($MANUAL_OVERRIDE). Skipping config deployment."
else
    deploy_config() {
        local FILENAME="$1"
        local SOURCE_FILE="$REPO_DIR/$FILENAME"
        local TARGET_FILE="$APT_CONF_DIR/$FILENAME"
        local CURRENT_REF="/home/loopsign/current-$FILENAME"

        if [[ ! -f "$SOURCE_FILE" ]]; then
            log "ERROR: $SOURCE_FILE not found in repo. Skipping $FILENAME."
            return 1
        fi

        if [[ -f "$CURRENT_REF" ]] && cmp -s "$SOURCE_FILE" "$CURRENT_REF"; then
            log "$FILENAME unchanged. Nothing to update."
            return 0
        fi

        if [[ -f "$TARGET_FILE" ]]; then
            local BACKUP_FILE="/tmp/${FILENAME}-backup-$(date +%F_%T)"
            sudo cp "$TARGET_FILE" "$BACKUP_FILE"
            log "Backup of previous $FILENAME saved to: $BACKUP_FILE"
        fi

        sudo cp "$SOURCE_FILE" "$TARGET_FILE"
        sudo chmod 644 "$TARGET_FILE"
        cp "$SOURCE_FILE" "$CURRENT_REF"
        log "Deployed $FILENAME to $APT_CONF_DIR."
    }

    deploy_config "20auto-upgrades"
    deploy_config "50unattended-upgrades"
fi

# --- Make sure the relevant services/timers are enabled and running ---
for UNIT in unattended-upgrades.service apt-daily.timer apt-daily-upgrade.timer; do
    sudo systemctl enable --now "$UNIT" >/dev/null 2>&1
    log "Ensured $UNIT is enabled."
done

log "Script finished."

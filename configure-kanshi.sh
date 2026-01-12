#!/usr/bin/env bash
set -euo pipefail

USER_HOME="/home/loopsign"
TARGET="${USER_HOME}/.config/kanshi/config"
MASTER="${USER_HOME}/ls-rpi5labwc/kanshi-config"

log() { echo "[seed-kanshi] $*"; }

# Preconditions
if [[ ! -f "$MASTER" ]]; then
  log "ERROR: Master config not found: $MASTER"
  exit 2
fi

mkdir -p "$(dirname "$TARGET")"

# Exit if target exists AND is non-empty
if [[ -s "$TARGET" ]]; then
  log "Target config exists and is non-empty. Leaving it untouched."
  exit 0
fi

log "Target config missing or empty. Seeding from master."

# Atomic write
tmp="$(mktemp "${TARGET}.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

cp -f "$MASTER" "$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$TARGET"
trap - EXIT

log "Seeded kanshi config."

# Restart kanshi
if pgrep -x kanshi >/dev/null 2>&1; then
  log "Restarting kanshi..."
  pkill -x kanshi || true
else
  log "kanshi not running; starting it..."
fi

nohup kanshi >/dev/null 2>&1 &

log "Done."
exit 0

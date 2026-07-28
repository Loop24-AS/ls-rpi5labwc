#!/bin/bash
set -e

OVERRIDE_DIR="/etc/systemd/system/apt-daily-upgrade.timer.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"
TMP_FILE="$(mktemp)"

cat > "$TMP_FILE" <<'EOF'
[Timer]
OnCalendar=
OnCalendar=Sun *-*-* 05:57
RandomizedDelaySec=0
Persistent=true
EOF

sudo mkdir -p "$OVERRIDE_DIR"

if sudo test -f "$OVERRIDE_FILE" && sudo cmp -s "$TMP_FILE" "$OVERRIDE_FILE"; then
    echo "apt-daily-upgrade.timer override already correct. No changes made."
    rm -f "$TMP_FILE"
    exit 0
fi

echo "Updating apt-daily-upgrade.timer override..."
sudo cp "$TMP_FILE" "$OVERRIDE_FILE"
rm -f "$TMP_FILE"
sudo systemctl daemon-reload
sudo systemctl restart apt-daily-upgrade.timer

echo "Done. Current timer:"
systemctl list-timers apt-daily-upgrade.timer

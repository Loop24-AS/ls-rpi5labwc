#!/bin/bash
TIMEOUT=3600
ELAPSED=0
LOG=/var/log/safe-reboot.log

apt_busy() {
    local state
    state=$(/usr/bin/systemctl show -p ActiveState --value apt-daily-upgrade.service)
    if [ "$state" = "active" ] || [ "$state" = "activating" ]; then
        return 0
    fi
    if /usr/bin/pgrep -x unattended-upgrade >/dev/null 2>&1; then
        return 0
    fi
    if /bin/fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

while apt_busy; do
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "$(date): Timed out waiting for apt to finish" >> "$LOG"
        exit 1
    fi
    sleep 30
    ELAPSED=$((ELAPSED + 30))
done

echo "$(date): Rebooting" >> "$LOG"
/usr/sbin/reboot

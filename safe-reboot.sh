#!/bin/bash

TIMEOUT=3600 # 1 hour max wait
ELAPSED=0

while /usr/bin/systemctl is-active --quiet apt-daily-upgrade.service; do
    if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo "$(date): Timed out waiting for apt-daily-upgrade" >> /var/log/safe-reboot.log
        exit 1
    fi
    sleep 30
    ELAPSED=$((ELAPSED + 30))
done

echo "$(date): Rebooting" >> /var/log/safe-reboot.log
/usr/sbin/reboot

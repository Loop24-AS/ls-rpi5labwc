#!/bin/bash

FLAG_FILE="/home/loopsign/ls-rpi5labwc/cache-refresh-flag"
DONE_FILE="/home/loopsign/cache-refresh-flag.done"

if [[ ! -f "$FLAG_FILE" ]]; then
    echo "No cache refresh flag found. Skipping."
    exit 0
fi

FLAG_VALUE=$(cat "$FLAG_FILE" | tr -d '[:space:]')
DONE_VALUE=$(cat "$DONE_FILE" 2>/dev/null | tr -d '[:space:]')

if [[ -z "$FLAG_VALUE" ]] || [[ "$FLAG_VALUE" == "$DONE_VALUE" ]]; then
    echo "Cache refresh flag already acted on ($FLAG_VALUE). Skipping."
    exit 0
fi

echo "Cache refresh flag detected ($FLAG_VALUE). Scheduling hard refresh in 5 minutes..."
sleep 300
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
wtype -M ctrl -M shift -k R -m shift -m ctrl
echo "$FLAG_VALUE" > "$DONE_FILE"
echo "Cache refresh performed and flag consumed at $(date)."

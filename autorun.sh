#!/bin/bash

exec > /tmp/autorun.log 2>&1
echo "Script started at $(date)"

# Restart udevmon to hide cursor
sudo systemctl restart udevmon

# Function to check internet connection and time sync
check_internet_and_time_sync() {
    # Flag to track whether the time has been synced
    synced=false
    # Flag to track whether the dialog box has been displayed
    displayed=false

    # Wait until the time has been synced
    while true; do
        # Check if system time is synchronized using systemd-timesyncd
        if timedatectl show -p NTPSynchronized --value | grep -q "yes"; then
            synced=true
            echo "System time has been synchronized."
            break
        fi

        # Display a message to the user if the time has not yet been synced and the dialog has not yet been displayed
        if ! $synced && ! $displayed; then
            echo "Displaying initial zenity message about time sync."
            zenity --info --text="Your LoopSign screen will start once a working internet connection is established and the player's time and date have been synced. Please note that this might take a couple of minutes. If your LoopSign screen won't start, please check your network and/or NTP settings." &
            displayed=true
        fi
        sleep 1
    done
}

# Function to update the repository using git reset --hard and git pull with rebase
update_repository() {
    local REPO_DIR="/home/loopsign/ls-rpi5labwc"
    local CONFIG_FILE="/home/loopsign/config"
    local BRANCH="prod"  # Default to "prod" for production
    local GITHUB_REPO_URL="https://github.com/Loop24-AS/ls-rpi5labwc.git"

    # Check if the configuration file exists
    if [ -f "$CONFIG_FILE" ]; then
        # Read the branch name directly from the configuration file
        BRANCH=$(cat "$CONFIG_FILE" | tr -d '[:space:]')

        # If the config file is empty, fall back to the default "prod"
        if [ -z "$BRANCH" ]; then
            echo "Config file is empty. Defaulting to 'prod'."
            BRANCH="prod"
        fi
    else
        echo "Config file does not exist. Creating it with the default branch 'prod'."
        echo "prod" > "$CONFIG_FILE"  # Create the config file with the default branch
    fi

    # Proceed with the repository update
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR"

        # Rename incorrect remote repository reference to 'origin' if necessary
        if git remote get-url StrictHostKeyChecking=no >/dev/null 2>&1; then
            echo "Renaming remote repository from 'StrictHostKeyChecking=no' to 'origin'..."
            git remote rename StrictHostKeyChecking=no origin
        fi

        # Force remote URL to be HTTPS (read-only)
        git remote set-url origin "$GITHUB_REPO_URL"

        echo "Fetching latest changes..."
        git fetch origin

        echo "Resetting local branch to match remote branch with correct branch..."
        git reset --hard origin/$BRANCH

        echo "Repository successfully updated and mirrored from remote branch $BRANCH."
    else
        echo "Repository directory does not exist or is not a git repository. Exiting."
        exit 1
    fi
}

# Function to schedule the master script update and restart
schedule_master_script_update_and_restart() {
    NEW_SCRIPT_PATH="/home/loopsign/ls-rpi5labwc/autorun.sh"
    CURRENT_SCRIPT_PATH="/home/loopsign/autorun.sh"

    if [ -f "$NEW_SCRIPT_PATH" ]; then
        NEW_HASH=$(sha256sum "$NEW_SCRIPT_PATH" | awk '{print $1}')
        CURRENT_HASH=$(sha256sum "$CURRENT_SCRIPT_PATH" | awk '{print $1}')

        if [ "$NEW_HASH" != "$CURRENT_HASH" ]; then
            echo "New version detected. Scheduling master script update and restart..."
            # Create a temporary script to perform the update and restart
            cat <<EOF > /home/loopsign/update_and_restart.sh
#!/bin/bash
sleep 2  # Ensure the original script has time to finish
mv "$NEW_SCRIPT_PATH" "$CURRENT_SCRIPT_PATH"
chmod +x "$CURRENT_SCRIPT_PATH"
/bin/bash "$CURRENT_SCRIPT_PATH"  # Restart the updated master script
rm -- "\$0"  # Delete this temporary script after execution
EOF
            chmod +x /home/loopsign/update_and_restart.sh
            nohup /home/loopsign/update_and_restart.sh > /dev/null 2>&1 &  # Run the update and restart in the background
            exit 0  # Exit the current script to allow the update to take place
        else
            echo "Master script is already up to date."
        fi
    else
        echo "No new master script found in the repository."
    fi
}

# Function to countdown while waiting for the secondary scripts to run
start_countdown() {
    (
        for i in {10..1}; do
            echo "# Your LoopSign screen will launch in about $i seconds..."
            echo "$(( (10 - i + 1) * 10 ))"  # Progress percentage
            sleep 1
        done
        echo "100"  # Ensure the progress reaches 100%
    ) | zenity --progress \
               --title="Countdown" \
               --text="Please wait..." \
               --percentage=0 \
               --auto-close \
               --no-cancel &
}

# Check internet connection and time synchronization and run updates if neccessary
check_internet_and_time_sync

# Pull the latest changes from the repository
update_repository

# Schedule the master script update and restart if needed
schedule_master_script_update_and_restart

# Kill any running Zenity dialogs
pkill zenity

## Set cron jobs
chmod +x /home/loopsign/ls-rpi5labwc/define-sudo-crontab.sh
sudo /home/loopsign/ls-rpi5labwc/define-sudo-crontab.sh

# Generate hash
chmod +x /home/loopsign/ls-rpi5labwc/hashgenerator.sh
/home/loopsign/ls-rpi5labwc/hashgenerator.sh

# Show countdown while secondary scripts run
start_countdown

# Run the updated scripts
cd /home/loopsign/ls-rpi5labwc
chmod +x autorefresh.sh loopsign.sh hidecursor.sh loopsignsplash.sh pishrink.sh hideaway-trigger.sh configure-kanshi.sh cache-refresh.sh # Adjust filenames as needed
./configure-kanshi.sh
nohup ./autorefresh.sh &
nohup ./cache-refresh.sh &
./loopsign.sh &
./hideaway-trigger.sh &

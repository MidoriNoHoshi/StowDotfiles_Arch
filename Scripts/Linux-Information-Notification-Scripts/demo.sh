#!/usr/bin/env bash

# --- SETUP ---
# Update these paths to match your actual wallpaper locations
WP_DIR="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal"
MORNING="$WP_DIR/Quitting_is_not_an_option!.jpg"
DAY="$WP_DIR/Less_talk..._more_action.webp"
NIGHT="$WP_DIR/Trust_Yourself._Eveything_Will_Be_Okay.png"
LOW_BAT="$WP_DIR/Trust_Yourself._Eveything_Will_Be_Okay.png"
MONITOR="eDP-1"

# Helper for Hyprland notifications
Notify() {
    hyprctl notify "$1" "$2" "$3" "fontsize:$4 $5"
}

# --- THE SHOW ---

echo "Starting recording sequence in 3 seconds..."
sleep 3

# 1. Start with Season Notification (Resetting the flag)
rm -f "/run/user/$UID/season_notified"
echo "Simulating Login / Season Discovery..."
Notify 1 6000 "rgb(ffb7c5)" 24 "Spring 春"
sleep 4

# 2. Morning Transition
echo "Simulating Morning..."
hyprctl hyprpaper wallpaper "${MONITOR},${MORNING}"
Notify 1 5000 "rgb(add8e6)" 24 "Entering matutinal hours"
sleep 5

# 3. Diurnal / Day Transition
echo "Simulating Daytime..."
hyprctl hyprpaper wallpaper "${MONITOR},${DAY}"
Notify 1 5000 "rgb(ffffff)" 24 "Daytime"
sleep 5

# 4. Trigger Your Info Notification Script
echo "Showing System Info..."
# Replace with the actual name of your first script (info/wifi/bt)
./your_info_script.sh 
sleep 6

# 5. Evening Transition
echo "Simulating Sunset..."
hyprctl hyprpaper wallpaper "${MONITOR},${NIGHT}"
Notify 1 5000 "rgb(4b0082)" 24 "Entering the crepuscule"
sleep 5

# 6. Low Battery Emergency (The Finale)
echo "Simulating Battery Critical..."
hyprctl hyprpaper wallpaper "${MONITOR},${LOW_BAT}"
# Triggering both Dunst (for the bar) and Hyprland (for the big text)
dunstify -u critical -h string:x-dunst-stack-tag:power1 -h int:value:15 "15:42" "Battery Critical: 15%"
Notify 0 9000 "rgb(ff0000)" 35 "Low Battery: 15% remaining"

echo "Sequence complete."

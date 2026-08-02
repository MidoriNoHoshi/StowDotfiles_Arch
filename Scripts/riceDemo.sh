#!/usr/bin/env bash

set -euo pipefail

DEMO_DIR="${HOME}/Videos/Demos"
mkdir -p "${DEMO_DIR}"
RECORDING_PATH="${DEMO_DIR}/hyprland_system_showcase_$(date +%Y%m%d_%H%M%S).mp4"

# Execution path to scripts
INFO_SCRIPT="${HOME}/.local/bin/information"
WALLPAPER_SCRIPT="${HOME}/.local/bin/wallpaperInfo"

pause() {
    sleep "${1:-2}"
}

echo "[*] Initializing Wayland Screen Recorder..."
wl-screenrec --filename "${RECORDING_PATH}" &
REC_PID=$!

trap 'kill -INT $REC_PID 2>/dev/null || true' EXIT

pause 2

echo "========================================="
echo " PHASE 1: Desktop Workspace & Tiling Showcase"
echo "========================================="

# Launch Terminal & Editor
hyprctl dispatch exec "[workspace 1] kitty -e nvim"
pause 2.5

# Split Tile
hyprctl dispatch exec "[workspace 1] kitty"
pause 1.5

# Launcher Demo
hyprctl dispatch exec "[workspace 1] fuzzel"
pause 1.5
hyprctl dispatch sendshortcut "Escape,,fuzzel"
pause 1.0

echo "========================================="
echo " PHASE 2: `information` State Matrix Showcase"
echo "========================================="

# 1. Base State Execution
echo "[+] Triggering Information: Default Steady State"
"$INFO_SCRIPT"
pause 3.0

# 2. Mocking Bluetooth Devices Stack
echo "[+] Demonstrating Bluetooth Stack Tags..."
dunstify -u low -h string:x-dunst-stack-tag:"BT_00:11:22:33:44:55" -h int:value:85 "󰂱 WH-1000XM4 󰋋" " 85%"
dunstify -u low -h string:x-dunst-stack-tag:"BT_AA:BB:CC:DD:EE:FF" -h int:value:40 "󰂱 MX Master 3S 󰍽" " 40%"
pause 3.0

# 3. Wi-Fi Rapid Trigger / Network Re-initialization
echo "[+] Demonstrating Wi-Fi Re-initialization (Rapid Press Sequence)..."
for i in {1..12}; do
    echo "$(date +%s)" >> /tmp/info_script_triggers
done
"$INFO_SCRIPT"
pause 3.5

echo "========================================="
echo " PHASE 3: `wallpaperInfo` Chronological & Battery Engine"
echo "========================================="

# Force Season Notification Flag Removal to trigger Season Banner
rm -f "/run/user/$UID/season_notified"
rm -f "/run/user/$UID/activeWallpaper"

echo "[+] Executing Wallpaper Engine Engine: Daytime Shift"
"$WALLPAPER_SCRIPT"
pause 3.0

# Force Low Battery Notification Override Simulation
echo "[+] Simulating Critical Low Battery Event (<20%)..."
dunstify -u critical -h string:x-dunst-stack-tag:power1 -h int:value:15 "$(date +"%H:%M")" "15% Battery Remaining"
hyprctl notify 0 9000 "rgb(ff0000)" "fontsize:35 Low Battery: 15% remaining"
pause 3.5

echo "========================================="
echo " PHASE 4: Workspace Navigation & Teardown"
echo "========================================="

# Switch to workspace 2 and launch browser
hyprctl dispatch workspace 2
pause 1.5
hyprctl dispatch exec "[workspace 2] zen-browser"
pause 3.0

# Return to Workspace 1
hyprctl dispatch workspace 1
pause 1.5

# Clean up open windows
hyprctl dispatch closewindow "class:kitty"
hyprctl dispatch closewindow "class:kitty"
hyprctl dispatch closewindow "class:zen-browser"
pause 1.5

echo "[*] Terminating Recording..."
kill -INT "${REC_PID}"
wait "${REC_PID}" 2>/dev/null || true

echo "[+] Video rendered successfully: ${RECORDING_PATH}"

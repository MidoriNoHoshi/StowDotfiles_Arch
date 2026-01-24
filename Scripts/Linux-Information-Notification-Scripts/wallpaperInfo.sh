#!/usr/bin/env bash
set -euo pipefail #Bash Unofficial Strict Mode.
# -e (errexit). If any command indicates an error, exit.
# -u (nounset). Unset variables are treated as errors.
# -o pipefail. Ensures that a pipeline returns a failure if any command in the pipe fails.

Bat0_Path="/sys/class/power_supply/BAT0"
Status=$(cat "$Bat0_Path"/status)
BatteryLevel=$(cat "$Bat0_Path"/capacity)
month=$(date +%m)

Monitor="eDP-1"
DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Less_talk..._more_action.webp"

season="Spring" # Set Spring as default, as it is my favourite.
month=$(date +%m)
case "$month" in
  03|04|05)
    season="Spring 春"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Less_talk..._more_action.webp"
    ;;
  06|07|08)
    season="Summer 夏"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Push yourself...jpg"
    ;;
  09|10|11)
    season="Autumn 秋"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Believe...jpg"
    ;;
  12|01|02)
    season="Winter 冬"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Mistakes are proof that you are trying.jpg"
    ;;
esac

LowBatteryWallpaper=/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/"Trust Yourself. Eveything Will Be Okay.png"

hour="$(date +%H)"
hour="${hour#0}"
hour="${hour:-0}"

MorningWallpaper=/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/"Quitting is not an option!.jpg"
NightWallpaper=/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/"Trust Yourself. Eveything Will Be Okay.png"
target="$DefaultWallpaper"

UpdateWallpaper() {
  local img="$1"
  hyprctl hyprpaper wallpaper "${Monitor},${img},cover" >/dev/null 2>&1 || true
}

if [[ "$Status" == "Discharging" ]] && (( BatteryLevel -le 20 )); then
 dunstify -h string:x-dunst-stack-tag:power1 -h int:value:"$BatteryLevel" "$(date +"%H:%M")" "$BatteryLevel"
 target="$LowBatteryWallpaper"
else
  if (( hour >= 18 || hour < 5 )); then
    target="$NightWallpaper"
  elif (( hour >= 5 && hour < 11 )); then
    target="$MorningWallpaper"
  else
    target="$DefaultWallpaper"
  fi
fi
 
UpdateWallpaper "$target"

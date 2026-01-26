#!/usr/bin/env bash

Bat0_Path="/sys/class/power_supply/BAT0"
if [[ -r "$Bat0_Path/status" && -r "$Bat0_Path/capacity" ]]; then
  Status=$(<"$Bat0_Path/status")
  BatteryLevel=$(<"$Bat0_Path/capacity")
else
  Status="Unknown"
  BatteryLevel=100
fi

Latitude="34.6937N"
Longitude="135.5023E"
Dawn=$(sunwait list civil dawn "$Latitude" "$Longitude" | head -n1)
Dusk=$(sunwait list civil dusk "$Latitude" "$Longitude" | head -n1)
# times in minutes. Nowtime = minutes since midnight (now)
Nowtime=$((10#$(date +%H)*60 + 10#$(date +%M)))
Dawntime=$((10#${Dawn%:*}*60 + 10#${Dawn#*:}))
(( Dawntime < 60 )) && Dawntime=60 # Prevents negative-time.
Dusktime=$((10#${Dusk%:*}*60 + 10#${Dusk#*:}))
(( Dusktime > 1439 )) && Dusktime=1439 # Clamp down dusk not later than midnight.
# This all goes straight out of the window in arctic conditions however.

month=$(date +%-m)

Monitor="eDP-1"
DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Less_talk..._more_action.webp"

season="Spring" # Set Spring as default, as it is my favourite.
case "$month" in
  3|4|5)
    season="Spring 春"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Less_talk..._more_action.webp"
    ;;
  6|7|8)
    season="Summer 夏"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Push yourself...jpg"
    ;;
  9|10|11)
    season="Autumn 秋"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Believe...jpg"
    ;;
  12|1|2)
    season="Winter 冬"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Mistakes are proof that you are trying.jpg"
    ;;
esac

LowBatteryWallpaper=/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/"Trust Yourself. Eveything Will Be Okay.png"

MorningWallpaper=/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/"Quitting is not an option!.jpg"
NightWallpaper=/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/"Trust Yourself. Eveything Will Be Okay.png"
target="$DefaultWallpaper"

# Path to store current wallpaper state
tmpState="/tmp/currentWallpaper"

UpdateWallpaper() {
  local img="$1"
  hyprctl hyprpaper wallpaper "${Monitor},${img},cover" >/dev/null 2>&1 || true
  echo "$img" > "$tmpState"
}

if [[ "$Status" == "Discharging" ]] && (( BatteryLevel -le 20 )); then
 dunstify -u critical -h string:x-dunst-stack-tag:power1 -h int:value:"$BatteryLevel" "$(date +"%H:%M")" "$BatteryLevel"
 target="$LowBatteryWallpaper"
else
  if (( Nowtime < Dawntime || Nowtime >= Dusktime )); then
    target="$NightWallpaper"
  elif (( Nowtime >= Dawntime - 60 && Nowtime < Dawntime + 120 )); then
    target="$MorningWallpaper"
  else
    target="$DefaultWallpaper"
  fi
fi

# Reading previous state
if [[ -f "$tmpState" ]]; then
  oldTarget=$(<"$tmpState")
else
  oldTarget=""
fi

if [[ "$target" != "$oldTarget" ]]; then
  UpdateWallpaper "$target"
fi

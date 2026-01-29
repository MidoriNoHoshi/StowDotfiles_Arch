#!/usr/bin/env bash

sleep 1
Bat0_Path="/sys/class/power_supply/BAT0"
if [[ -r "$Bat0_Path/status" && -r "$Bat0_Path/capacity" ]]; then
  Status=$(<"$Bat0_Path/status")
  BatteryLevel=$(<"$Bat0_Path/capacity")
else
  Status="Unknown"
  BatteryLevel=100
fi

Notify() {
  local level="${1:-1}"
  local ms="${2:-3000}"
  local colour="${3:-rgb(ff0000)}"
  local fontsize="${4:-24}"
  shift 4
  local msg="$*"

  hyprctl notify "$level" "$ms" "$colour" "fontsize:$fontsize $msg"
}

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
    seasoncolour="rgb(ffb7c5)"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Less_talk..._more_action.webp"
    ;;
  6|7|8)
    season="Summer 夏"
    seasoncolour="rgb(ffd700)"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Push_yourself...jpg"
    ;;
  9|10|11)
    season="Autumn 秋"
    seasoncolour="rgb(e67e22)"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Believe...jpg"
    ;;
  12|1|2)
    season="Winter 冬"
    seasoncolour="rgb(f0f8ff)"
    DefaultWallpaper="/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/Mistakes_are_proof_that_you_are_trying.jpg"
    ;;
esac
flagFile="/run/user/$UID/season_notified"
if [[ ! -f "$flagFile" ]]; then
  Notify 1 6000 "$seasoncolour" 24 "$season"
    touch "$flagFile"
fi

LowBatteryWallpaper=/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/"Trust_Yourself._Eveything_Will_Be_Okay.png"

MorningWallpaper=/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/"Quitting_is_not_an_option!.jpg"
NightWallpaper=/home/nemi/Desktop/Wallpapers/chill-chill-joirnal/"Trust_Yourself._Eveything_Will_Be_Okay.png"
target="$DefaultWallpaper"

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

# Path to store current wallpaper state
tmpState="/run/user/$UID/activeWallpaper"
sessionFlag="/run/user/$UID/wallpaperInit"
mkdir -p "$(dirname "$tmpState")"

UpdateWallpaper() {
  local img="$1"
  sleep 0.2
  hyprctl hyprpaper wallpaper "${Monitor},${img}"
  echo "$img" > "$tmpState"
}

# Reading previous state
if [[ -f "$tmpState" ]]; then
  # read -r activeTarget < "$tmpState"
  activeTarget=$(<"$tmpState")
else
  activeTarget=""
fi

uptime_s=$(awk '{print$1}' /proc/uptime | cut -d. -f1)
if ([[ ! -f "$sessionFlag" ]] && (( uptime_s < 300 ))) || [ "$target" != "$activeTarget" ]; then
  UpdateWallpaper "$target"
  touch "$sessionFlag"
  if [[ "$target" == "$NightWallpaper" ]]; then
  # hyprctl notify 1 3000 "rgb(81007f)" "fontsize:24 Entering the crepuscule"
  Notify 1 5000 "rgb(4b0082)" 24 "Entering the crepuscule"
  elif [[ "$target" == "$MorningWallpaper" ]]; then
    Notify 1 5000 "rgb(add8e6)" 24 "Entering matutinal hours"
  elif [[ "$target" == "$LowBatteryWallpaper" ]]; then
    Notify 0 9000 "rgb(ff0000)" 35 "Low Battery: $BatteryLevel% remaining"
  else
    # hyprctl notify 1 3000 "rgb(ff0000)" "fontsize:24 Entering photopic phase"
    Notify 1 5000 "rgb(ffffff)" 24 "Commencing diurnal cycle"
  fi
fi

#!/usr/bin/env bash
brightness=$(brightnessctl get)
max_brightness=$(brightnessctl max)
percent=$(echo "scale=0; 100 * $brightness / $max_brightness" | bc) # Set scale = 0 for no decimal points.
# percent=$((100 * (brightness / max_brightness)


icon=""
if [ "$percent" -ge 75 ]; then
  icon="󰃚"
elif [ "$percent" -ge 50 ]; then
  icon="󰃛"
elif [ "$percent" -ge 25 ]; then
  icon="󰃜"
elif [ "$percent" -ge 0 ]; then
  icon=" "
fi

dunstify -h string:x-dunst-stack-tag:brightness -h int:value:"$percent" "$icon Brightness: ${percent}%"
exit 0

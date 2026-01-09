#!/usr/bin/env bash

Bat0_Path="/sys/class/power_supply/BAT0"
power=$(cat "$Bat0_Path"/capacity)
status=$(cat "$Bat0_Path"/status)
icon="󰁹"
statusIcon="󰁹"
Keymap=$(hyprctl devices | awk '/Keyboards:/ {in_kb=1} in_kb && /active keymap:/ {keymap=$0} in_kb && /main: yes/ {sub(/.*active keymap: /,"",keymap); print keymap; exit}')

if ["$power" -ge 100 ]; then
  icon="󰁹" # Full
elif [ "$power" -ge 90 ]; then
  icon="󰂂"
elif [ "$power" -ge 80 ]; then
  icon="󰂁"
elif [ "$power" -ge 70 ]; then
  icon="󰂀"
elif [ "$power" -ge 60 ]; then
  icon="󰁿"
elif [ "$power" -ge 50 ]; then
  icon="󰁾"
elif [ "$power" -ge 40 ]; then
  icon="󰁽"
elif [ "$power" -ge 30 ]; then
  icon="󰁼"
elif [ "$power" -ge 20 ]; then
  icon="󰁻"
elif [ "$power" -ge 0 ]; then
  icon="󰁺"
fi

if [ "$status" = "Charging" ]; then
  statusIcon="󰶼 Charging"
elif [ "$status" = "Discharging" ]; then
  statusIcon="󰶹 Discharging"
elif [ "$status" = "Full" ]; then
  statusIcon="󰽙 Full"
elif [ "$status" = "Not charging" ]; then
  statusIcon="󰝷 Not Charging"
fi

# Update, I also want it to check the status of the wifi. Station wlan0)

Wifi_state=$(iwctl station wlan0 show | grep "State" | awk '{print $2}')
Wifi_SSID=$(iwctl station wlan0 show | grep "Connected network" | awk '{print $3}')
# Wifi_RSSI=$(iwctl station wlan0 show | grep -w "RSSI" | awk '{print $2, $3}') # RSSI stands for Received Signal Strength Indicator and gives the current signal strength in dBm (decibel-milliwatts). Note, the closer the value is to 0, the better.
RSSI_value=$(iwctl station wlan0 show | grep -w "RSSI" | awk '{print $2}' | sed 's/-//')
Wifi_Icon="󰤯"

if [ -z "$RSSI_value" ]; then
  Wifi_Icon="󰤫 "
elif [ "$RSSI_value" -le 50 ]; then
  Wifi_Icon="󰤨 "
elif [ "$RSSI_value" -le 65 ]; then
  Wifi_Icon="󰤥 "
elif [ "$RSSI_value" -le 75 ]; then
  Wifi_Icon="󰤢 "
elif [ "$RSSI_value" -le 85 ]; then
  Wifi_Icon="󰤟 "
else
  Wifi_Icon="󰤯 "
fi

# Just realised, this "string:x-dunst-stack-tag" part just assigns the notificatios "tag". In other, here it just prevents dunst from showing how many times this notification was called. Doesn't actually do anything in terms of the content of the notification.
# dunstify -h string:x-dunst-stack-tag:"$power" -h int:value:"$power" "$(date +"%b %d %a %H:%M")" "$statusIcon $icon: $power% \n Wifi: $Wifi_state $Wifi_SSID $Wifi_RSSI"
dunstify -h string:x-dunst-stack-tag:"info" -h int:value:"$power" "$(date +"%b %d %a %H:%M")" "$Wifi_Icon-$RSSI_value $Wifi_state: $Wifi_SSID \n  $Keymap \n $statusIcon $icon $power%"
exit 0

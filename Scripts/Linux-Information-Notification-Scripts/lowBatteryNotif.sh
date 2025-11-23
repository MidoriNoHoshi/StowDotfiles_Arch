#!/usr/bin/env bash

Bat0_Path="/sys/class/power_supply/BAT0"
Status=$(cat "$Bat0_Path"/status)
BatteryLevel=$(cat "$Bat0_Path"/capacity)

# Don't notify battery warning if the laptop is charging.
if [["$Status" != "Discharging" ]]; then
  exit 0
fi

if (( BatteryLevel <= 10 )); then
  dunstify -h string:x-dunst-stack-tag:power1 -h int:value:"$BatteryLevel" "$(date %H:%M)" "$BatteryLevel"
  exit 0
fi

if (( BatteryLevel <= 20 )); then
 dunstify -h string:x-dunst-stack-tag:power1 -h int:value:"$BatteryLevel" "$(date %H:%M)" "$BatteryLevel"
 exit 0
fi
 


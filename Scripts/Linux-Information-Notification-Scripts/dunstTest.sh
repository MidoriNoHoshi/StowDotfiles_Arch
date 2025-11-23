#!/usr/bin/env bash
BatteryPower=$(cat "/sys/class/power_supply/BAT0/capacity")

dunstify -h string:x-dunst-stack-tag:"testing" -h string:fgcolor:#aee9d7 -h string:bgcolor:#1f0909 -h int:value:"$BatteryPower" -h string:hlcolor:#abc0ed  "$(date +"%H:%M")" "$BatteryPower"

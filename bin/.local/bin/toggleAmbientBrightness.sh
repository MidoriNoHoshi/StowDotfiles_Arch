#!/usr/bin/env bash

if systemctl --user is-active --quiet ambient-brightness.service; then
  systemctl --user stop ambient-brightness.service
  notify-send \
    -h string:x-dunst-stack-tag:ambient_brightness_off \
    -u low \
    -i display-brightness-off \
    "Adaptive Brightness" "Deactivated"
else
  systemctl --user start ambient-brightness.service
  $HOME/.local/bin/ambient_brightness_daemon.py --trigger
  BRIGHTNESSCTL=$(brightnessctl i | grep -oP '\(\d+%\)' | tr -d '()%')

  notify-send \
    -h string:x-dunst-stack-tag:ambient_brightness_on \
    -h int:value:"$BRIGHTNESSCTL" \
    -u normal \
    "Adaptive Brightness" "Activated $BRIGHTNESSCTL"
fi

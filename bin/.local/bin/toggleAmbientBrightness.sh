#!/usr/bin/env bash

if systemctl --user is-active --quiet ambient-brightness.service; then
  systemctl --user stop ambient-brightness.service
  notify-send \
    -h string:x-dunst-stack-tag:ambient_brightness \
    -u low \
    -i display-brightness-off \
    "Adaptive Brightness" "Deactivated"
else
  # Take one reading before starting the daemon, so the two never fight over
  # the camera and the notification shows the level that was actually set.
  "$HOME/.local/bin/ambient-brightness" --once
  systemctl --user start ambient-brightness.service
  percent=$(brightnessctl -m | cut -d, -f4 | tr -d '%')

  notify-send \
    -h string:x-dunst-stack-tag:ambient_brightness \
    -h int:value:"$percent" \
    -u normal \
    "Adaptive Brightness" "Activated ${percent}%"
fi

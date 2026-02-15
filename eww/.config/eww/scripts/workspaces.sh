#!/usr/bin/env bash
# Generates a JSON array of workspaces for eww
generate() {
  hyprctl workspaces -j | jq -c 'sort_by(.id)'
}

# Listen for changes to update instantly
generate
socat -u  UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.s - | while read -r line; do
  generate
done

#!/usr/bin/env bash

## --- DATA GATHERING ---
# Volume info (Pipewire)
VOL_DATA=$(wpctl get-volume @DEFAULT_SINK@)
VOL_SINK=$(wpctl inspect @DEFAULT_SINK@ | grep 'node.description' | cut -d'"' -f2)

# Music info (Playerctl)
PLAYER_STATUS=$(playerctl status 2>/dev/null)
SONG_TITLE=$(playerctl metadata title 2>/dev/null)
SONG_ARTIST=$(playerctl metadata artist 2>/dev/null)

## --- VOLUME LOGIC ---
get_vol_icon() {
    local vol_percent=$(echo "$(echo "$VOL_DATA" | awk '{print $2}') * 100 / 1" | bc)
    if echo "$VOL_DATA" | grep -q '\[MUTED\]'; then
        echo "󰝟"
    elif [ "$vol_percent" -ge 60 ]; then echo "󰕾";
    elif [ "$vol_percent" -ge 20 ]; then echo "󰖀";
    else echo "󰕿"; fi
}

## --- MEDIA LOGIC ---
get_media_info() {
    if [[ -z "$PLAYER_STATUS" ]]; then
        echo "Nothing Playing"
    else
        # Truncate long titles for small widgets
        echo "${SONG_TITLE:0:25} - ${SONG_ARTIST:0:15}"
    fi
}

get_media_icon() {
    if [[ "$PLAYER_STATUS" == "Playing" ]]; then
        echo "󰏤" # Pause icon
    else
        echo "󰐊" # Play icon
    fi
}

## --- EXECUTION ---
case "$1" in
    --vol-icon)   get_vol_icon ;;
    --vol-text)   echo "$(echo "$(echo "$VOL_DATA" | awk '{print $2}') * 100 / 1" | bc)%" ;;
    --sink)       echo "$VOL_SINK" ;;
    --media-text) get_media_info ;;
    --media-icon) get_media_icon ;;
    --toggle)     playerctl play-pause ;;
esac

#!/bin/bash

# Get the most recent player that is actually playing or paused
PLAYER_STATUS=$(playerctl status 2>/dev/null)

if [ -z "$PLAYER_STATUS" ]; then
    if [[ "$1" == "--song" ]]; then echo "Offline"; fi
    exit 0
fi

case "$1" in
    --song)
        # Displays "Title - Artist"
        playerctl metadata --format "{{ title }} - {{ artist }}"
        ;;
    --status)
        if [[ "$PLAYER_STATUS" == "Playing" ]]; then
            echo "" # Play icon (Nerd Font)
        else
            echo "奈" # Pause icon
        fi
        ;;
    --cover)
        # Fetches the URL (YouTube) or local path (MPV/VLC)
        art_url=$(playerctl metadata mpris:artUrl 2>/dev/null)
        if [[ "$art_url" == http* ]]; then
            curl -s "$art_url" -o /tmp/.music_cover.jpg
            echo "/tmp/.music_cover.jpg"
        elif [[ "$art_url" == file://* ]]; then
            echo "${art_url#file://}"
        else
            echo "/path/to/your/default_icon.png"
        fi
        ;;
    --toggle)
        playerctl play-pause
        ;;
    --next)
        playerctl next
        ;;
    --prev)
        playerctl previous
        ;;
esac

# #!/bin/bash
#
# # This automatically finds the active player (Spotify, Firefox, MPD, etc.)
# PLAYER_STATUS=$(playerctl status 2>/dev/null)
#
# get_status() {
#     if [[ "$PLAYER_STATUS" == "Playing" ]]; then
#         echo "" # Play icon
#     else
#         echo "奈" # Pause/Stop icon
#     fi
# }
#
# get_title() {
#     # Filters out empty titles and truncated strings
#     title=$(playerctl metadata title 2>/dev/null)
#     if [[ -z "$title" ]]; then
#         echo "No Media"
#     else
#         echo "$title"
#     fi
# }
#
# get_artist() {
#     # If it's a YouTube video, 'artist' is usually the Channel Name
#     artist=$(playerctl metadata artist 2>/dev/null)
#     if [[ -z "$artist" ]]; then
#         echo "Unknown Artist/Channel"
#     else
#         echo "$artist"
#     fi
# }
#
# get_cover() {
#     # This works for YouTube (via browser) and local files!
#     # It gets the URL or local path of the thumbnail
#     art_url=$(playerctl metadata mpris:artUrl 2>/dev/null)
#
#     if [[ "$art_url" == file://* ]]; then
#         echo "${art_url#file://}"
#     elif [[ "$art_url" == http* ]]; then
#         curl -s "$art_url" -o /tmp/.music_cover.jpg
#         echo "/tmp/.music_cover.jpg"
#     else
#         echo "/path/to/default/icon.png"
#     fi
# }
#
# # Logic to handle arguments
# case "$1" in
#     --title)  get_title ;;
#     --artist) get_artist ;;
#     --status) get_status ;;
#     --cover)  get_cover ;;
#     --toggle) playerctl play-pause ;;
#     --next)   playerctl next ;;
#     --prev)   playerctl previous ;;
# esac

#!/bin/bash

if pgrep -x "wf-recorder" > /dev/null; then
    pkill -SIGINT -x "wf-recorder"
    notify-send "Recording" "Stopped and saved to ~/Videos" -i video-display
    exit 0
fi

FILENAME="$HOME/Videos/recording_$(date +%F_%H-%M-%S).mp4"

wf-recorder -g "$(slurp)" -f "$FILENAME"

#!/bin/bash

# Configuration path
KBD_CONF="$HOME/dotfiles/kmonad/.config/kmonad/usbKeyboard.kbd"
# PID file to track the process
PID_FILE="/tmp/kmonad_ducky.pid"

if [ -f "$PID_FILE" ]; then
    echo "Stopping KMonad for Ducky..."
    kill $(cat "$PID_FILE") && rm "$PID_FILE"
    echo "Stopped."
else
    echo "Starting KMonad for Ducky..."
    sudo kmonad "$KBD_CONF" & 
    echo $! > "$PID_FILE"
    echo "Started with PID $(cat "$PID_FILE")."
fi

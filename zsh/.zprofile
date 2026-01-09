if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
  # -z "$WAYLAND_DISPLAY". If not already in a wayland session.
  # "$XDG_VTNR -eq 1". On TTY1.
  exec dbus-run-session start-hyprland
  # Creates DBus session bus: "DBUS_SESSION_BUS_ADDRESS"
fi

# Thus, hyprland is launched within the DBus session.

#!/usr/bin/env bash

wireguardDirectory="/etc/wireguard/"

if [ "$EUID" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

mapfile -t configs < <(find "$wireguardDirectory" -maxdepth 1 -name '*.conf' -printf '%f\n' 2>/dev/null | sed 's/\.conf$//')
[ "${#configs[@]}" -eq 0 ] && exit 1
choice=$(printf "%s\n" "${configs[@]}" | fzf --prompt="VPN >")
[ -z "$choice" ] && exit 0

active=$(wg show interfaces)

if echo "$active" | grep -qx "$choice"; then
  wg-quick down "$choice"
else
  for ia in $active; do
    wg-quick down "$ia"
  done
  wg-quick up "$choice"
fi

#!/usr/bin/env bash

# Get VPN country from wireguard interface name
iface=$(wg show interfaces 2>/dev/null)

if [[ -z "$iface" ]]; then
  echo "󰝷"
else
  case "$iface" in
    *-NL-*)  echo "🇳🇱 NL" ;;
    *-JP-*)  echo "🇯🇵 JP" ;;
    *-CAN-*) echo "🇨🇦 CA" ;;
    *-NOR-*) echo "🇳🇴 NO" ;;
    *-US-*)  echo "🇺🇸 US" ;;
    *-PL-*)  echo "🇵🇱 PL" ;;
    *-CH-*)  echo "🇨🇭 CH" ;;
    *-MX-*)  echo "🇲🇽 MX" ;;
    *-SG-*)  echo "🇸🇬 SG" ;;
    *)       echo "󰶼" ;;
  esac
fi

#!/usr/bin/env bash

# Keyboard layout information: ------------------------------------------------------------------
Keymap=$(hyprctl devices | awk '/Keyboards:/ {in_kb=1} in_kb && /active keymap:/ {keymap=$0} in_kb && /main: yes/ {sub(/.*active keymap: /,"",keymap); print keymap; exit}')


# Battery related information: ------------------------------------------------------------------
Bat0_Path="/sys/class/power_supply/BAT0"
power=$(cat "$Bat0_Path"/capacity)
status=$(cat "$Bat0_Path"/status)
icon="󰁹"
statusIcon="󰁹"

if [ "$power" -ge 100 ]; then
  icon="󰁹" # Full
elif [ "$power" -ge 90 ]; then
  icon="󰂂"
elif [ "$power" -ge 80 ]; then
  icon="󰂁"
elif [ "$power" -ge 70 ]; then
  icon="󰂀"
elif [ "$power" -ge 60 ]; then
  icon="󰁿"
elif [ "$power" -ge 50 ]; then
  icon="󰁾"
elif [ "$power" -ge 40 ]; then
  icon="󰁽"
elif [ "$power" -ge 30 ]; then
  icon="󰁼"
elif [ "$power" -ge 20 ]; then
  icon="󰁻"
elif [ "$power" -ge 0 ]; then
  icon="󰁺"
fi

if [ "$status" = "Charging" ]; then
  statusIcon="󰶼 Charging"
elif [ "$status" = "Discharging" ]; then
  statusIcon="󰶹 Discharging"
elif [ "$status" = "Full" ]; then
  statusIcon="󰽙 Full"
elif [ "$status" = "Not charging" ]; then
  statusIcon="󰝷 Not Charging"
fi


# Wifi related information: ---------------------------------------------------------------------
iwctl=$(iwctl station wlan0 show 2>/dev/null)

Wifi_state=$(awk '/State/ {print $2}' <<< "$iwctl")
Wifi_SSID=$(awk '/Connected network/ {print $3}' <<< "$iwctl")
if [ -z "$Wifi_SSID" ]; then
  Wifi_SSID="󰝷 "
fi
RSSI_value=$(awk '/AverageRSSI/ {print $2}' <<< "$iwctl" | sed 's/-//')
# Wifi_state=$(iwctl station wlan0 show | grep "State" | awk '{print $2}')
# Wifi_SSID=$(iwctl station wlan0 show | grep "Connected network" | awk '{print $3}')
# Wifi_RSSI=$(iwctl station wlan0 show | grep -w "RSSI" | awk '{print $2, $3}') # RSSI stands for Received Signal Strength Indicator and gives the current signal strength in dBm (decibel-milliwatts). Note, the closer the value is to 0, the better.
# RSSI_value=$(iwctl station wlan0 show | grep -w "RSSI" | awk '{print $2}' | sed 's/-//')
Wifi_Icon="󰤯"

if [ -z "$RSSI_value" ]; then
  Wifi_Icon="󰤫 "
  RSSI_value="0"
elif [ "$RSSI_value" -le 50 ]; then
  Wifi_Icon="󰤨 "
elif [ "$RSSI_value" -le 65 ]; then
  Wifi_Icon="󰤥 "
elif [ "$RSSI_value" -le 75 ]; then
  Wifi_Icon="󰤢 "
elif [ "$RSSI_value" -le 85 ]; then
  Wifi_Icon="󰤟 "
else
  Wifi_Icon="󰤯 "
fi


# VPN related information: ----------------------------------------------------------------------
iface=$(wg show interfaces 2>/dev/null)
vvv="󰖂 VPN:"

if [[ -z "$iface" ]]; then
  vpn_status="${vvv}󰝷 "
else
  case "$iface" in
    *-NL-*)  vpn_status="${vvv}🇳🇱 NL" ;;
    *-JP-*)  vpn_status="${vvv}🇯🇵 JP" ;;
    *-CAN-*) vpn_status="${vvv}🇨🇦 CA" ;;
    *-NOR-*) vpn_status="${vvv}🇳🇴 NO" ;;
    *-US-*) vpn_status="${vvv}🇺🇸 US" ;;
    *-PL-*) vpn_status="${vvv}🇵🇱 PL" ;;
    *-CH-*) vpn_status="${vvv}🇨🇭 CH" ;;
    *-MX-*) vpn_status="${vvv}🇲🇽 MX" ;;
    *-SG-*) vpn_status="${vvv}🇸🇬 SG" ;;
    *)     vpn_status="${vvv}󰶼 " ;;
  esac
fi


# Bluetooth related information: ----------------------------------------------------------------

# If bluetooth is off, it should show in the main notification.
BT_powered=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')
if [ "$BT_powered" = "no" ]; then
  BT_state="\n Off"
else
  BT_state="\n󰂲 Disconnected"
  BT_macs=$(bluetoothctl devices | cut -d ' ' -f 2)
  Connected_icon=" " 
  for mac in $BT_macs; do
    BT_info=$(bluetoothctl info "$mac")

    if echo "$BT_info" | grep -q "Connected: yes"; then
      # If device is connected, clear BT_state so it doesn't show in main notification.
      BT_state=""

      Connected_name=$(echo "$BT_info" | awk -F': ' '/Name:/ {print $2}')
      Connected_battery=$(echo "$BT_info" | awk -F '[()]' '/Battery Percentage:/ {print $2}')
      stack_tag="BT_$mac"

      if [ -n "$Connected_battery" ]; then
        if [ "$Connected_battery" -ge 100 ]; then
          Connected_icon=" "
        elif [ "$Connected_battery" -ge 80 ]; then
          Connected_icon=" "
        elif [ "$Connected_battery" -ge 60 ]; then
          Connected_icon=" "
        elif [ "$Connected_battery" -ge 40 ]; then
          Connected_icon=" "
        elif [ "$Connected_battery" -ge 20 ]; then
          Connected_icon=" "
        fi
        DeviceType=$(echo "$BT_info" | grep "Icon:" | awk '{print $2}')
        case "$DeviceType" in
          audio-headphones|audio-card) DeviceIcon=" " ;;
          input-mouse)                 DeviceIcon="󰍽 " ;;
          input-keyboard)              DeviceIcon="󰌌 " ;;
          phone)                       DeviceIcon=" " ;;
          *)                           DeviceIcon="󰝷 " ;;
        esac
        dunstify -u low -h string:x-dunst-stack-tag:"$stack_tag" -h int:value:"$Connected_battery" "󰂱 $Connected_name $DeviceIcon" "$Connected_icon $Connected_battery%"
      else
        # Device is connected but has no battery reported
        dunstify -u low -h string:x-dunst-stack-tag:"$stack_tag" "󰂱 $Connected_name $DeviceIcon" "Connected"
      fi
    fi
  done
fi

# Just realised, this "string:x-dunst-stack-tag" part just assigns the notificatios "tag". In other, here it just prevents dunst from showing how many times this notification was called. Doesn't actually do anything in terms of the content of the notification.
# dunstify -h string:x-dunst-stack-tag:"$power" -h int:value:"$power" "$(date +"%b %d %a %H:%M")" "$statusIcon $icon: $power% \n Wifi: $Wifi_state $Wifi_SSID $Wifi_RSSI"
dunstify -u normal -h string:x-dunst-stack-tag:"info" -h int:value:"$power" "$(date +"%H:%M %b %d %a")" "$Wifi_Icon-$RSSI_value $Wifi_state: \n 󰀂 $Wifi_SSID \n $vpn_status \n  $Keymap \n $statusIcon $icon $power%$BT_state"

exit 0

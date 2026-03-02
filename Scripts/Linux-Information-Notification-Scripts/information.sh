#!/usr/bin/env bash

# Keyboard layout information: ------------------------------------------------------------------
Keymap=$(hyprctl devices | awk '/Keyboards:/ {in_kb=1} in_kb && /active keymap:/ {keymap=$0} in_kb && /main: yes/ {sub(/.*active keymap: /,"",keymap); print keymap; exit}')
if [ "$Keymap" = "English (US)" ]; then
  Keymap=""
else
  Keymap="\n  $Keymap"
fi


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

Wifi_fullInfo=" $Wifi_Icon-$RSSI_value $Wifi_state: \n 󰀂 $Wifi_SSID"

# VPN related information: ----------------------------------------------------------------------
# Going to mix with Wifi info a little bit.
iface=$(wg show interfaces 2>/dev/null)
vvv="󰖂 VPN:"

if [ "$Wifi_state" = "disconnected" ]; then
  vpn_status=""
  Wifi_fullInfo=" $Wifi_Icon-$RSSI_value $Wifi_state"
else
  if [[ -z "$iface" ]]; then
    vpn_status=""
    # vpn_status="${vvv}󰝷 "
  else
    case "$iface" in
      *-NL-*)  vpn_status="${vvv}🇳🇱 NL" ;;
      *-JP-*)  vpn_status="${vvv}🇯🇵 JP" ;;
      *-CA-*) vpn_status="${vvv}🇨🇦 CA" ;;
      *-NOR-*) vpn_status="${vvv}🇳🇴 NO" ;;
      *-US-*) vpn_status="${vvv}🇺🇸 US" ;;
      *-PL-*) vpn_status="${vvv}🇵🇱 PL" ;;
      *-CH-*) vpn_status="${vvv}🇨🇭 CH" ;;
      *-MX-*) vpn_status="${vvv}🇲🇽 MX" ;;
      *-SG-*) vpn_status="${vvv}🇸🇬 SG" ;;
      *)     vpn_status="${vvv}󰶼 " ;;
    esac
  fi
    if [ -n "$vpn_status" ]; then
      vpn_status="\n $vpn_status"
    fi
  # vpn_status="\n $vpn_status"
fi


# Bluetooth related information: ----------------------------------------------------------------

# If bluetooth is off, it should show in the main notification.
BT_powered=$(cat /sys/class/bluetooth/hci0/rfkill*/state 2>/dev/null) # This reads on hardware. bluetoothctl power off doesn't stop bluetooth model radio transmission. sudo rfkill block bluetooth to cease radio transmission.
# - sudo rfkill block bluetooth
# - sudo rfkill unblock bluetooth
#
BT_state=""
if [ "$BT_powered" != "1" ]; then
  BT_state="\n  Off"
else
# Get connected devices using the Heredoc trick
  connected_devs=$(bluetoothctl << EOF
devices Connected
exit
EOF)

  # BT_Display_Names=$(echo "$connected_devs" | grep "Device " | cut -d ' ' -f 3- | paste -sd "," -)
  BT_macs=$(echo "$connected_devs" | grep "Device " | cut -d ' ' -f 2)

  if [ -z "$BT_macs" ]; then
    BT_state="\n 󰂲 Disconnected"
  else
    # BT_state="\n 󰂱 $BT_Display_Names"

    for mac in $BT_macs; do
      BT_mac_info=$(bluetoothctl << EOF
info $mac
exit
EOF
)
      Connected_name=$(echo "$BT_mac_info" | awk -F': ' '/Name:/ {print $2}')
      Connected_battery=$(echo "$BT_mac_info" | grep "Battery Percentage" | awk -F '[()]' '{print $2}' | tr -d '% ')
      Device_class=$(echo "$BT_mac_info" | grep "Icon:" | awk '{print $2}')
      stack_tag="BT_$mac"

      case "$Device_class" in
        audio-headphones|audio-card) DeviceIcon=" " ;;
        input-mouse)                 DeviceIcon="󰍽 " ;;
        input-keyboard)              DeviceIcon="󰌌 " ;;
        phone)                       DeviceIcon=" " ;;
        *)                           DeviceIcon="󰝷 " ;;
      esac

      Connected_icon="There's an error?"

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

          dunstify -u low -h string:x-dunst-stack-tag:"$stack_tag" -h int:value:"$Connected_battery" "󰂱 $Connected_name $DeviceIcon" "$Connected_icon $Connected_battery%"
        else
          dunstify -u low -h string:x-dunst-stack-tag:"$stack_tag" "󰂱 $Connected_name $DeviceIcon" "Connected"
      fi
    done
  fi 
fi

# Just realised, this "string:x-dunst-stack-tag" part just assigns the notificatios "tag". In other, here it just prevents dunst from showing how many times this notification was called. Doesn't actually do anything in terms of the content of the notification.
# dunstify -h string:x-dunst-stack-tag:"$power" -h int:value:"$power" "$(date +"%b %d %a %H:%M")" "$statusIcon $icon: $power% \n Wifi: $Wifi_state $Wifi_SSID $Wifi_RSSI"
dunstify -u normal -h string:x-dunst-stack-tag:"info" -h int:value:"$power" " $(date +"%H:%M %b %d %a")" "$Wifi_fullInfo$vpn_status$BT_state$Keymap \n\n $statusIcon $icon $power%"

exit 0

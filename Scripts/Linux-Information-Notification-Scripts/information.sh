#!/usr/bin/env bash

# ── Rapid-trigger detection ──────────────────────────────────────────────────────
TRIGGER_FILE="/tmp/info_script_triggers"
MONITOR_PID_FILE="/tmp/info_ip_monitor.pid"
MONITOR_ACTIVE_FILE="/tmp/info_ip_monitor.active"
NO_IP_REMIND_FILE="/tmp/info_no_ip_last_remind"
TRIGGER_WINDOW=8
MONITOR_DURATION=7200
NO_IP_REMIND_INTERVAL=30

get_ip() {
  ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1
}

_is_monitor_alive() {
  [ -f "$MONITOR_ACTIVE_FILE" ] || return 1
  local pid
  pid=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

_start_monitor() {
  touch "$MONITOR_ACTIVE_FILE"
  echo "$BASHPID" > "$MONITOR_PID_FILE"
  local deadline last_ip current_ip
  deadline=$(( $(date +%s) + MONITOR_DURATION ))
  last_ip=$(get_ip)
  while (( $(date +%s) < deadline )); do
    sleep 2
    current_ip=$(get_ip)
    if [ -z "$current_ip" ] && [ -n "$last_ip" ]; then
      # dunstify -u critical -h string:x-dunst-stack-tag:"ip-monitor" \
        # "󰤭 IP Lost" "wlan0 no longer has an IPv4 address"
        
      dunstify -u critical -h string:x-dunst-stack-tag:"ip-monitor" \
        "󰤭 IP 消失" "wlan0 の IPv4 アドレスが失われました" 

    elif [ -n "$current_ip" ] && [ -z "$last_ip" ]; then
      rm -f "$NO_IP_REMIND_FILE"
      # dunstify -u low -h string:x-dunst-stack-tag:"ip-restored" \
      #   "󰤨 IP Restored" "wlan0 got address: $current_ip"

      dunstify -u low -h string:x-dunst-stack-tag:"ip-restored" \
        "󰤨 IP 復旧" "wlan0 がアドレスを取得しました: $current_ip"

    elif [ -n "$current_ip" ] && [ "$current_ip" != "$last_ip" ]; then
      # dunstify -u low -h string:x-dunst-stack-tag:"ip-restored" \
      #   "󰤨 IP Changed" "wlan0: $last_ip → $current_ip"

      dunstify -u low -h string:x-dunst-stack-tag:"ip-restored" \
        "󰤨 IP 変更" "wlan0: $last_ip → $current_ip"

    fi
    last_ip="$current_ip"
  done
  # dunstify -u low -h string:x-dunst-stack-tag:"ip-monitor" \
  #   "󰤨 IP Monitor Ended" "120-minute watch on wlan0 complete"

  dunstify -u low -h string:x-dunst-stack-tag:"ip-monitor" \
    "󰤨 IP 監視終了" "wlan0 の120分間の監視が完了しました"

  rm -f "$MONITOR_ACTIVE_FILE" "$MONITOR_PID_FILE" "$NO_IP_REMIND_FILE"
}

_kill_monitor() {
  rm -f "$MONITOR_ACTIVE_FILE"
  local old_pid
  old_pid=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
  [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
  rm -f "$MONITOR_PID_FILE" "$NO_IP_REMIND_FILE"
}

# ── Capture iwctl once, reused by both the monitor block and main display ────────
iwctl=$(iwctl station wlan0 show 2>/dev/null)
wifi_state=$(awk '/State/ {print $2}' <<< "$iwctl")
current_ip=$(get_ip)

# ── No-IP path ───────────────────────────────────────────────────────────────────
if [ "$wifi_state" = "connected" ] && [ -z "$current_ip" ]; then
  now=$(date +%s)
  last_remind=$(cat "$NO_IP_REMIND_FILE" 2>/dev/null)
  time_since=$(( now - ${last_remind:-0} ))

  if (( time_since >= NO_IP_REMIND_INTERVAL )); then
    echo "$now" > "$NO_IP_REMIND_FILE"
    if _is_monitor_alive; then
      # dunstify -u critical -h string:x-dunst-stack-tag:"ip-monitor" \
      #   "󰤭 Still No IP" "wlan0 connected but no IPv4 — monitor active"

      dunstify -u critical -h string:x-dunst-stack-tag:"ip-monitor" \
        "󰤭 IP 未取得" "接続済みですが IPv4 がありません — 監視中"
    else
      _kill_monitor
      > "$TRIGGER_FILE"
      ( _start_monitor ) &
      disown
      # dunstify -u critical -h string:x-dunst-stack-tag:"ip-monitor" \
      #   "󰤭 No IP Address" "wlan0 connected but no IPv4 — monitor started"

      dunstify -u critical -h string:x-dunst-stack-tag:"ip-monitor" \
        "󰤭 IP アドレスなし" "接続済みですが IPv4 がありません — 監視開始"
    fi
  fi

# ── Normal path: require 12 rapid presses ────────────────────────────────────────
else
  rm -f "$NO_IP_REMIND_FILE"
  now=$(date +%s)
  mapfile -t timestamps < <(
    [ -f "$TRIGGER_FILE" ] && cat "$TRIGGER_FILE"
    echo "$now"
  )
  filtered=()
  for ts in "${timestamps[@]}"; do
    (( now - ts <= TRIGGER_WINDOW )) && filtered+=("$ts")
  done
  printf '%s\n' "${filtered[@]}" > "$TRIGGER_FILE"

  if (( ${#filtered[@]} >= 12 )); then
    > "$TRIGGER_FILE"
    if ! _is_monitor_alive; then
      ( _start_monitor ) &
      disown
      # dunstify -u low -h string:x-dunst-stack-tag:"ip-monitor" \
      #   "󰤨 IP Monitor Started" "Watching wlan0 for 120 minutes..."

      dunstify -u low -h string:x-dunst-stack-tag:"ip-monitor" \
        "󰤨 IP 監視開始" "wlan0 を120分間監視します..."

    else
      _kill_monitor
      ( _start_monitor ) &
      disown
      # dunstify -u low -h string:x-dunst-stack-tag:"ip-monitor" \
      #   "󰤨 IP Monitor Restarted" "Timer reset to 120 minutes"

      dunstify -u low -h string:x-dunst-stack-tag:"ip-monitor" \
        "󰤨 IP 監視再開" "タイマーを120分にリセットしました"

    fi
  fi
fi
# ── End rapid-trigger block ───────────────────────────────────────────────────────


# Keyboard layout: ────────────────────────────────────────────────────────────────
Keymap=$(hyprctl devices | awk '/Keyboards:/ {in_kb=1} in_kb && /active keymap:/ {keymap=$0} in_kb && /main: yes/ {sub(/.*active keymap: /,"",keymap); print keymap; exit}')
if [ "$Keymap" = "English (US)" ]; then
  Keymap=""
else
  Keymap="\n  キーボード: $Keymap"
fi


# Battery: ────────────────────────────────────────────────────────────────────────
Bat0_Path="/sys/class/power_supply/BAT0"
power=$(cat "$Bat0_Path"/capacity)
status=$(cat "$Bat0_Path"/status)
icon="󰁹"
statusIcon="󰁹"

if [ "$power" -ge 100 ]; then
  icon="󰁹"
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
  statusIcon="󰶼 充電中"
elif [ "$status" = "Discharging" ]; then
  statusIcon="󰶹 放電中"
elif [ "$status" = "Full" ]; then
  statusIcon="󰽙 満充電"
elif [ "$status" = "Not charging" ]; then
  statusIcon="󰝷 非充電"
fi


# Wifi (reuse $iwctl already captured above): ─────────────────────────────────────
Wifi_state="$wifi_state"
if [ "$wifi_state" == "Connected" ]; then
  Wifi_state="接続済み"
else
  Wifi_state="切断"
fi

Wifi_SSID=$(awk '/Connected network/ {print $3}' <<< "$iwctl")
if [ -z "$Wifi_SSID" ]; then
  Wifi_SSID="󰝷  なし"
fi
RSSI_value=$(awk '/AverageRSSI/ {print $2}' <<< "$iwctl" | sed 's/-//')
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

# VPN: ────────────────────────────────────────────────────────────────────────────
iface=$(wg show interfaces 2>/dev/null)
vvv="󰖂 VPN:"

if [ "$wifi_state" = "disconnected" ]; then
  vpn_status=""
  Wifi_fullInfo=" $Wifi_Icon-$RSSI_value $Wifi_state"
else
  if [[ -z "$iface" ]]; then
    vpn_status=""
  else
    case "$iface" in
      *-NL-*)  vpn_status="${vvv}🇳🇱 NL オランダ" ;;
      *-JP-*)  vpn_status="${vvv}🇯🇵 JP 日本" ;;
      *-CA-*)  vpn_status="${vvv}🇨🇦 CA カナダ" ;;
      *-NOR-*) vpn_status="${vvv}🇳🇴 NO ノルウェー" ;;
      *-US-*)  vpn_status="${vvv}🇺🇸 US アメリカ" ;;
      *-PL-*)  vpn_status="${vvv}🇵🇱 PL ポーランド" ;;
      *-CH-*)  vpn_status="${vvv}🇨🇭 CH スイス" ;;
      *-MX-*)  vpn_status="${vvv}🇲🇽 MX メキシコ" ;;
      *-SG-*)  vpn_status="${vvv}🇸🇬 SG シンガポール" ;;
      *)       vpn_status="${vvv}󰶼 " ;;
    esac
  fi
  if [ -n "$vpn_status" ]; then
    vpn_status="\n $vpn_status"
  fi
fi


# Bluetooth: ──────────────────────────────────────────────────────────────────────
BT_powered=$(cat /sys/class/bluetooth/hci0/rfkill*/state 2>/dev/null)
BT_state=""
if [ "$BT_powered" != "1" ]; then
  # BT_state="\n  Off"
  BT_state="\n  オフ"
else
  connected_devs=$(bluetoothctl << EOF
devices Connected
exit
EOF)
  BT_macs=$(echo "$connected_devs" | grep "Device " | cut -d ' ' -f 2)

  if [ -z "$BT_macs" ]; then
    # BT_state="\n 󰂲 Disconnected"
    BT_state="\n 󰂲 未接続"
  else
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
        audio-headphones|audio-card) DeviceIcon=" " ;;
        input-mouse)                 DeviceIcon="󰍽 " ;;
        input-keyboard)              DeviceIcon="󰌌 " ;;
        phone)                       DeviceIcon=" " ;;
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
        else
          Connected_icon=" " # <20%
        fi
        dunstify -u low -h string:x-dunst-stack-tag:"$stack_tag" -h int:value:"$Connected_battery" "󰂱 $Connected_name $DeviceIcon" "$Connected_icon $Connected_battery%"
      else
        # dunstify -u low -h string:x-dunst-stack-tag:"$stack_tag" "󰂱 $Connected_name $DeviceIcon" "Connected"
        dunstify -u low -h string:x-dunst-stack-tag:"$stack_tag" "󰂱 $Connected_name $DeviceIcon" "接続済み"
      fi
    done
  fi
fi

# dunstify -u normal -h string:x-dunst-stack-tag:"info" -h int:value:"$power" " $(date +"%H:%M %b %d %a")" "$Wifi_fullInfo$vpn_status$BT_state$Keymap \n\n $statusIcon $icon $power%"

dunstify -u normal -h string:x-dunst-stack-tag:"info" -h int:value:"$power" " $(LANG=ja_JP.UTF-8 date +"%-H:%M %-m月%-d日 %A")" "$Wifi_fullInfo$vpn_status$BT_state$Keymap \n\n $statusIcon $icon $power%"
 

exit 0

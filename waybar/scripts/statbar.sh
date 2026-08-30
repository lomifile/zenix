#!/usr/bin/env bash
# statbar.sh <kind>  ->  "<icon> <bar> <pct>%"
# kind: cpu | memory | battery | volume

kind="${1:-cpu}"
cells=10
filled_ch="█"
empty_ch=" "

pct=0
icon=""

case "$kind" in
cpu)
  read -r _ u n s i _ </proc/stat
  t1=$((u + n + s + i))
  idle1=$i
  sleep 0.3
  read -r _ u n s i _ </proc/stat
  t2=$((u + n + s + i))
  idle2=$i
  dt=$((t2 - t1))
  di=$((idle2 - idle1))
  [ "$dt" -gt 0 ] && pct=$(((100 * (dt - di)) / dt)) || pct=0
  icon="󰻠"
  ;;
memory)
  pct=$(free | awk '/Mem:/ {printf "%d", $3/$2*100}')
  icon=""
  ;;
battery)
  bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
  if [ -n "$bat" ] && [ -r "$bat/capacity" ]; then
    pct=$(cat "$bat/capacity")
    st=$(cat "$bat/status" 2>/dev/null)
    case "$st" in
    Charging) icon="󰂄" ;;
    Full) icon="󰚥" ;;
    *) icon="󰁹" ;;
    esac
  else
    pct=0
    icon="󱉞"
  fi
  ;;
volume)
  if command -v wpctl >/dev/null 2>&1; then
    raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    if echo "$raw" | grep -q MUTED; then
      echo "󰝟 muted"
      exit 0
    fi
    vol=$(echo "$raw" | awk '{print $2}')
    pct=$(awk -v v="$vol" 'BEGIN{printf "%d", v*100}')
  fi
  icon="󰕾"
  ;;
esac

[ "$pct" -gt 100 ] && pct=100
[ "$pct" -lt 0 ] && pct=0

fill=$(((pct * cells + 50) / 100))
bar=""
for ((c = 0; c < cells; c++)); do
  if [ "$c" -lt "$fill" ]; then bar="${bar}${filled_ch}"; else bar="${bar}${empty_ch}"; fi
done

printf "%s %s %d%%\n" "$icon" "$bar" "$pct"

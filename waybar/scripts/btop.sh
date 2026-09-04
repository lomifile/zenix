#!/usr/bin/env bash
set -euo pipefail

preset="${1:-0}"
class="zenix.btop"

if command -v hyprctl >/dev/null 2>&1 &&
  hyprctl -j clients 2>/dev/null | grep -q "\"class\": \"$class\""; then
  hyprctl dispatch focuswindow "class:^${class//./\\.}$" >/dev/null
  exit 0
fi

exec ghostty "--class=$class" --title=btop -e btop -p "$preset"

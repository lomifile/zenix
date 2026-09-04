import QtQuick

QtObject {
  readonly property var groups: [
    {
      title: "Windows",
      items: [
        { keys: "SUPER + Q", label: "Close window" },
        { keys: "SUPER + V", label: "Float / unfloat" },
        { keys: "SUPER + F", label: "Fullscreen" },
        { keys: "SUPER + P", label: "Pseudo tile" },
        { keys: "SUPER + J", label: "Toggle split direction" },
        { keys: "SUPER + E", label: "Fold workspace into tabs" },
        { keys: "SUPER + Tab", label: "Next tab" },
        { keys: "SUPER + ⇧ + Tab", label: "Previous tab" },
        { keys: "SUPER + drag", label: "Move window" },
        { keys: "SUPER + right drag", label: "Resize window" }
      ]
    },
    {
      title: "Focus",
      items: [
        { keys: "SUPER + ←→↑↓", label: "Move focus" },
        { keys: "SUPER + ⇧ + ←→↑↓", label: "Move window" }
      ]
    },
    {
      title: "Workspaces",
      items: [
        { keys: "SUPER + 1…0", label: "Go to workspace" },
        { keys: "SUPER + ⇧ + 1…0", label: "Send window to workspace" },
        { keys: "CTRL + ←", label: "Previous existing workspace" },
        { keys: "CTRL + →", label: "Next existing workspace" },
        { keys: "SUPER + A", label: "Scratchpad" },
        { keys: "SUPER + ⇧ + A", label: "Send window to scratchpad" }
      ]
    },
    {
      title: "Launch",
      items: [
        { keys: "SUPER + ⏎", label: "Terminal (ghostty)" },
        { keys: "SUPER + Space", label: "Launcher (wofi)" },
        { keys: "SUPER + ⇧ + E", label: "File manager" },
        { keys: "SUPER + L", label: "Lock screen" }
      ]
    },
    {
      title: "Popups",
      items: [
        { keys: "SUPER + M", label: "Power" },
        { keys: "SUPER + S", label: "Sound" },
        { keys: "SUPER + B", label: "Bluetooth" },
        { keys: "SUPER + W", label: "Wi-Fi" },
        { keys: "SUPER + D", label: "Docker containers" },
        { keys: "SUPER + ⇧ + H", label: "This list" }
      ]
    },
    {
      title: "Screen & clipboard",
      items: [
        { keys: "SUPER + ⇧ + P", label: "Screenshot to clipboard" },
        { keys: "SUPER + ⇧ + S", label: "Screenshot a region" },
        { keys: "SUPER + ⇧ + V", label: "Clipboard history" }
      ]
    },
    {
      title: "Media",
      items: [
        { keys: "Volume ▲▼", label: "Output volume" },
        { keys: "Mute", label: "Mute output" },
        { keys: "Brightness ▲▼", label: "Screen brightness" },
        { keys: "Play", label: "Play / pause" },
        { keys: "Next / Prev", label: "Skip track" }
      ]
    },
    {
      title: "Waybar",
      items: [
        { keys: "click cpu", label: "btop, CPU preset" },
        { keys: "click memory", label: "btop, memory and disks" },
        { keys: "click clock", label: "Calendar and agenda" },
        { keys: "click sound", label: "Sound popup" },
        { keys: "click network", label: "Wi-Fi popup" },
        { keys: "click bluetooth", label: "Bluetooth popup" }
      ]
    },
    {
      title: "Containers popup",
      items: [
        { keys: "j / k", label: "Move selection" },
        { keys: "⏎", label: "Start or stop" },
        { keys: "r", label: "Restart" },
        { keys: "l", label: "Logs" },
        { keys: "s", label: "Shell in" },
        { keys: "d", label: "lazydocker" },
        { keys: "/", label: "Filter" }
      ]
    },
    {
      title: "zsh",
      items: [
        { keys: "CTRL + F", label: "tmux sessionizer" },
        { keys: "CTRL + A", label: "Attach a session" },
        { keys: "CTRL + L", label: "List sessions" },
        { keys: "CTRL + Q", label: "Detach" }
      ]
    },
    {
      title: "tmux",
      items: [
        { keys: "prefix + f", label: "Sessionizer" },
        { keys: "prefix + |", label: "Split vertically" },
        { keys: "prefix + -", label: "Split horizontally" },
        { keys: "prefix + r", label: "Reload config" }
      ]
    }
  ]
}

-- Sonoma-flavored Hyprland config (0.55+ Lua / hl API)

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

local terminal = "ghostty"
local fileManager = "thunar"
local menu = "pkill -x wofi || wofi --show drun"

local LAPTOP = "eDP-1"

local applied_state = nil

local function reconfigure_monitors()
	local has_external = false
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= LAPTOP then
			has_external = true
		end
	end

	local wanted = has_external and "off" or "on"
	if wanted == applied_state then
		return
	end
	applied_state = wanted

	if has_external then
		hl.monitor({ output = LAPTOP, disabled = true })
	else
		hl.monitor({ output = LAPTOP, mode = "preferred", position = "auto", scale = "auto" })
	end
end

hl.on("monitor.layout_changed", reconfigure_monitors)

hl.env("HYPRCURSOR_THEME", "macOS-hypr")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "macOS")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.on("hyprland.start", function()
	reconfigure_monitors()
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("waybar")
	hl.exec_cmd('qs -p "$HOME/.config/zenix/shell"')
	hl.exec_cmd("mako")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("nm-applet --indicator")
	hl.exec_cmd("blueman-applet")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

hl.config({
	general = {
		gaps_in = 6,
		gaps_out = { top = 4, right = 8, bottom = 8, left = 8 },
		border_size = 2,
		col = {
			active_border = { colors = { "rgba(ffffffcc)", "rgba(ffffff55)" }, angle = 45 },
			inactive_border = "rgba(ffffff22)",
		},
		resize_on_border = true,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 12,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 0.96,
		shadow = {
			enabled = true,
			range = 25,
			render_power = 3,
			color = 0x40000000,
		},
		blur = {
			enabled = true,
			size = 8,
			passes = 3,
			vibrancy = 0.22,
		},
	},

	animations = { enabled = true },

	dwindle = { preserve_split = true },

	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},

	input = {
		kb_layout = "us",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = { natural_scroll = true, tap_to_click = true },
	},
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

local mod = "SUPER"

hl.bind(mod .. " + Q", hl.dsp.window.close())
-- hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + M", hl.dsp.exit())
hl.bind(mod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))

hl.bind(mod .. " + D", hl.dsp.exec_cmd("zenix-shell shell toggle zenix.containers"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("zenix-shell shell toggle zenix.bluetooth"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("zenix-shell shell toggle zenix.wifi"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("zenix-shell shell toggle zenix.audio"))

hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))

hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

for i = 1, 10 do
	local key = i % 10
	hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + A", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + A", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind("CTRL + left", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("CTRL + right", hl.dsp.focus({ workspace = "e+1" }))

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
	name = "fix-xwayland-drags",
	match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
	no_focus = true,
})
for _, c in ipairs({ "pavucontrol", "org.pulseaudio.pavucontrol", "blueman-manager", "nm-connection-editor" }) do
	hl.window_rule({ match = { class = c }, float = true })
end

for _, spec in ipairs({
	{ class = "^zenix\\.container-logs$", size = { 1100, 700 } },
	{ class = "^zenix\\.container-shell$", size = { 1000, 620 } },
	{ class = "^zenix\\.lazydocker$", size = { 1280, 800 } },
}) do
	hl.window_rule({ match = { class = spec.class }, float = true })
	hl.window_rule({ match = { class = spec.class }, center = true })
	hl.window_rule({ match = { class = spec.class }, size = spec.size })
end

hl.layer_rule({ match = { namespace = "wofi" }, blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ match = { namespace = "^zenix-" }, blur = true, ignore_alpha = 0.4 })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true })

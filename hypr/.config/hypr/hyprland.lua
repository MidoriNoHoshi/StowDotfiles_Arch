local home = os.getenv("HOME")
local terminal = "kitty"
local file_manager = "nemo"
local menu = "fuzzel"
local browser = "zen-browser"
local mainMod = "SUPER"

hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "auto", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("INPUT_METHOD", "fcitx")

hl.env("HYPRSHOT_DIR", home .. "/Pictures/Screenshots")

hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 8,
		border_size = 1,
		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
		col = {
			active_border = "rgba(d8d8d8cc)",
		},
	},
	decoration = {
		rounding = 8,
		rounding_power = 2,
		active_opacity = 1.0,
		inactive_opacity = 1.0,
		shadow = {
			enabled = true,
			range = 4,
			render_power = 3,
			color = 0xee1a1a1a,
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},
	animations = {
		enabled = true,
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
	},
	input = {
		kb_layout = "us",
		special_fallthrough = true,
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = false,
			disable_while_typing = true,
			tap_to_click = true,
		},
	},
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Aggressive Ease-In (Dwells at start, snaps to 1)
hl.curve("snapIn", { type = "bezier", points = { { 0.7, 0.0 }, { 0.84, 0.0 } } })

-- Snappy Ease-In-Out (Slow build, vertical velocity spike in mid-flight)
hl.curve("midSnap", { type = "bezier", points = { { 0.85, 0.0 }, { 0.15, 1.0 } } })

-- Overshoot Snap (Holds, accelerates, slightly overshoots target before resting)
hl.curve("overshootSnap", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "quick" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "quick", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

hl.device({
	name = "elan0676:00-04f3:3195-touchpad",
	enabled = true,
	disable_while_typing = true,
})

hl.device({
	name = "elecom-shellpha",
	sensitivity = -0.6,
})

hl.device({
	name = "tpps/2-elan-trackpoint",
	sensitivity = -0.4,
})

hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0, border_size = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0, border_size = 0 })

hl.window_rule({
	name = "suppress-maximize",
	match = { class = ".*" },
	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(file_manager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region --region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(home .. "/.local/bin/screen-recorder"))
hl.bind("F12", hl.dsp.exec_cmd(home .. "/.local/bin/information"))
hl.bind("F9", hl.dsp.exec_cmd(home .. "/.local/bin/fuzzel-hyprpicker"))

hl.bind("mouse:274", hl.dsp.exec_cmd(home .. "/.local/bin/ocr-capture"))

hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + grave", hl.dsp.focus({ workspace = 11 }))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = 11 }))

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+ --limit 1.2 && " .. home .. "/.local/bin/volume"),
	{ repeating = true, locked = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%- && " .. home .. "/.local/bin/volume"),
	{ repeating = true, locked = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && " .. home .. "/.local/bin/volume"),
	{ repeating = true, locked = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ repeating = true, locked = true }
)

hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+ && " .. home .. "/.local/bin/brightness"),
	{ repeating = true, locked = true }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%- && " .. home .. "/.local/bin/brightness"),
	{ repeating = true, locked = true }
)
hl.bind(mainMod .. " + XF86MonBrightnessUp", hl.dsp.exec_cmd(home .. "/.local/bin/toggleAmbientBrightness.sh"))
hl.bind(mainMod .. " + XF86MonBrightnessDown", hl.dsp.exec_cmd(home .. "/.local/bin/toggleAmbientBrightness.sh"))

hl.bind(
	"XF86PickupPhone",
	hl.dsp.exec_cmd(home .. "/.local/bin/mouse-sensitivity down"),
	{ repeating = true, locked = true }
)
hl.bind(
	"XF86HangupPhone",
	hl.dsp.exec_cmd(home .. "/.local/bin/mouse-sensitivity up"),
	{ repeating = true, locked = true }
)

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.on("hyprland.start", function()
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("fcitx5 -d --replace")
	hl.exec_cmd("dunst")
	hl.exec_cmd("rm -f /run/user/1000/activeWallpaper")
	hl.exec_cmd("sleep 3 && " .. home .. "/.local/bin/wallpaperInfo")
	hl.exec_cmd("sleep 3 && " .. home .. "/.local/bin/information")
end)

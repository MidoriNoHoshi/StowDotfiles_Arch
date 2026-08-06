---@module 'hl'
local hl = require("hyprland")

-- Local Variables
local terminal = "kitty"
local file_manager = "nemo"
local menu = "fuzzel"
local browser = "zen-browser"
local home = os.getenv("HOME")

--------------------------------------------------------------------------------
-- Monitors
--------------------------------------------------------------------------------
-- hl.monitor({
--     output = "eDP-1",
--     mode = "1920x1200@60hz",
--     position = "auto",
--     scale = 1,
-- })
--
-- hl.monitor({
--     output = "HDMI-A-1",
--     mode = "preferred",
--     position = "auto",
--     scale = "auto",
-- })

--------------------------------------------------------------------------------
-- Environment Variables
--------------------------------------------------------------------------------
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("INPUT_METHOD", "fcitx")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", 24)
hl.env("HYPRCURSOR_SIZE", 24)
hl.env("HYPRSHOT_DIR", home .. "/Pictures/Screeneshots")

--------------------------------------------------------------------------------
-- Core Configuration
--------------------------------------------------------------------------------
hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 8,
		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
		border_size = 1,
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
			color = "rgba(1a1a1aee)",
		},
		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
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
		kb_layout = "us,us",
		kb_variant = ",dvorak",
		kb_options = "grp:alt_shift_toggle",
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

--------------------------------------------------------------------------------
-- Animations
--------------------------------------------------------------------------------
hl.bezier("easeOutQuint", 0.23, 1, 0.32, 1)
hl.bezier("easeInOutCubic", 0.65, 0.05, 0.36, 1)
hl.bezier("linear", 0, 0, 1, 1)
hl.bezier("almostLinear", 0.5, 0.5, 0.75, 1.0)
hl.bezier("quick", 0.15, 0, 0.1, 1)

hl.animation("global", true, 10, "default")
hl.animation("border", true, 5.39, "easeOutQuint")
hl.animation("windows", true, 4.79, "easeOutQuint")
hl.animation("windowsIn", true, 4.1, "easeOutQuint", "popin 87%")
hl.animation("windowsOut", true, 1.49, "linear", "popin 87%")
hl.animation("fadeIn", true, 1.73, "almostLinear")
hl.animation("fadeOut", true, 1.46, "almostLinear")
hl.animation("fade", true, 3.03, "quick")
hl.animation("layers", true, 3.81, "easeOutQuint")
hl.animation("layersIn", true, 4, "easeOutQuint", "fade")
hl.animation("layersOut", true, 1.5, "linear", "fade")
hl.animation("fadeLayersIn", true, 1.79, "almostLinear")
hl.animation("fadeLayersOut", true, 1.39, "almostLinear")
hl.animation("workspaces", true, 1.94, "almostLinear", "fade")
hl.animation("workspacesIn", true, 1.21, "almostLinear", "fade")
hl.animation("workspacesOut", true, 1.94, "almostLinear", "fade")

--------------------------------------------------------------------------------
-- Devices
--------------------------------------------------------------------------------
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

--------------------------------------------------------------------------------
-- Workspace & Window Rules
--------------------------------------------------------------------------------
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0, border = 0, rounding = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0, border = 0, rounding = 0 })

hl.window_rule({
	name = "suppress_event_maximize",
	match = { class = ".*" },
})

hl.window_rule({
	name = "no_focus_on_unnamed_xwayland",
	match = { class = "^$", title = "^$", xwayland = true },
})

--------------------------------------------------------------------------------
-- Keybindings
--------------------------------------------------------------------------------
local mainMod = "SUPER"

-- Application Execution & Window Control
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(file_manager))
hl.bind(mainMod .. " + V", hl.dsp.window.float())
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

-- Utility Binds
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region --region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(home .. "/.local/bin/screen-recorder"))
hl.bind("F12", hl.dsp.exec_cmd(home .. "/.local/bin/information"))
hl.bind("F9", hl.dsp.exec_cmd(home .. "/.local/bin/fuzzel-hyprpicker"))

-- Navigation (Vim Keys)
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

-- Programmatic Workspace Bindings (1 through 10)
for i = 1, 10 do
	local key = tostring(i % 10) -- 1..9, then 0 for workspace 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Workspace 11 (Grave / Tilde)
hl.bind(mainMod .. " + grave", hl.dsp.focus({ workspace = 11 }))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = 11 }))

-- Special Workspace
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Mouse Binds
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Hardware / Media Keys
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 1%+ --limit 1.2 && " .. home .. "/.local/bin/volume"),
	{ locked = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%- && " .. home .. "/.local/bin/volume"),
	{ locked = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && " .. home .. "/.local/bin/volume"),
	{ locked = true }
)
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+ && " .. home .. "/.local/bin/brightness"),
	{ locked = true }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%- && " .. home .. "/.local/bin/brightness"),
	{ locked = true }
)
hl.bind("XF86PickupPhone", hl.dsp.exec_cmd(home .. "/.local/bin/mouse-sensitivity down"), { locked = true })
hl.bind("XF86HangupPhone", hl.dsp.exec_cmd(home .. "/.local/bin/mouse-sensitivity up"), { locked = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

--------------------------------------------------------------------------------
-- Autostart Engine
--------------------------------------------------------------------------------
hl.on("hyprland.start", function()
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("fcitx5-remote -r")
	hl.exec_cmd("fcitx5 -d --replace")
	hl.exec_cmd("dunst")
	hl.exec_cmd("rm /run/user/1000/activeWallpaper")
	hl.exec_cmd("sleep 3 && " .. home .. "/.local/bin/wallpaperInfo")
	hl.exec_cmd("sleep 3 && " .. home .. "/.local/bin/information")
end)

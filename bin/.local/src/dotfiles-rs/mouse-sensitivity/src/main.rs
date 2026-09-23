//! Step the libinput sensitivity of one mouse up/down and show a dunst bar.
//!
//! Hyprland has no way to *read* a per-device sensitivity back (`hyprctl -j
//! devices` only reports `defaultSpeed`, which is always 0.0), so the current
//! value is kept in a small state file inside the Hyprland instance's runtime
//! dir. It is seeded from the `hl.device({ name = ..., sensitivity = ... })`
//! block in hyprland.lua, and re-seeded whenever that file is edited (Hyprland
//! auto-reloads on save, which resets the device back to the config value).
//!
//! The new value is applied by talking to Hyprland's IPC socket directly
//! rather than spawning `hyprctl`.

use std::env;
use std::fs;
use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::process::{Command, exit};
use std::time::SystemTime;

const STEP: f64 = 0.1;
const MAX_SENSE: f64 = 1.0;
const MIN_SENSE: f64 = -1.0;

const DEVICE_NAME: &str = "elecom-shellpha";

fn hypr_dir() -> Option<PathBuf> {
    let runtime = env::var_os("XDG_RUNTIME_DIR")?;
    let sig = env::var_os("HYPRLAND_INSTANCE_SIGNATURE")?;
    Some(PathBuf::from(runtime).join("hypr").join(sig))
}

fn config_path() -> PathBuf {
    let base = env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(env::var_os("HOME").unwrap_or_default()).join(".config"));
    base.join("hypr/hyprland.lua")
}

fn mtime(path: &PathBuf) -> Option<SystemTime> {
    fs::metadata(path).and_then(|m| m.modified()).ok()
}

/// Finds `sensitivity = X` inside the `hl.device({...})` block naming DEVICE_NAME.
fn sensitivity_from_config(config: &str) -> Option<f64> {
    let name_at = config.find(&format!("\"{DEVICE_NAME}\""))?;
    let block_start = config[..name_at].rfind('{')?;
    let block_end = name_at + config[name_at..].find('}')?;
    let block = &config[block_start..block_end];

    let after = &block[block.find("sensitivity")? + "sensitivity".len()..];
    let after = after.trim_start().strip_prefix('=')?.trim_start();
    let end = after
        .find(|c: char| !(c.is_ascii_digit() || matches!(c, '-' | '+' | '.')))
        .unwrap_or(after.len());
    after[..end].parse().ok()
}

fn current_sensitivity(state: Option<&PathBuf>) -> f64 {
    let config = config_path();
    if let Some(state) = state {
        // A saved value is only trusted if the config hasn't been edited since.
        let fresh = match (mtime(state), mtime(&config)) {
            (Some(s), Some(c)) => s >= c,
            (Some(_), None) => true,
            _ => false,
        };
        if fresh {
            if let Some(v) = fs::read_to_string(state).ok().and_then(|s| s.trim().parse().ok()) {
                return v;
            }
        }
    }
    fs::read_to_string(&config)
        .ok()
        .and_then(|c| sensitivity_from_config(&c))
        .unwrap_or(0.0)
}

fn hypr_eval(lua: &str) -> std::io::Result<String> {
    let sock = hypr_dir()
        .ok_or_else(|| std::io::Error::other("not running under Hyprland"))?
        .join(".socket.sock");
    let mut stream = UnixStream::connect(sock)?;
    stream.write_all(format!("/eval {lua}").as_bytes())?;
    let mut reply = String::new();
    stream.read_to_string(&mut reply)?;
    Ok(reply)
}

fn round2(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

/// "55.0" -> "55", "57.5" stays "57.5".
fn format_percent(percent: f64) -> String {
    let formatted = format!("{percent:.1}");
    formatted.trim_end_matches('0').trim_end_matches('.').to_string()
}

fn main() {
    let direction = match env::args().nth(1).as_deref() {
        Some("up") => 1.0,
        Some("down") => -1.0,
        _ => {
            eprintln!("usage: mouse-sensitivity up|down");
            exit(1);
        }
    };

    let state = hypr_dir().map(|d| d.join("mouse-sensitivity"));
    let current = current_sensitivity(state.as_ref());
    let new_sense = round2(current + direction * STEP).clamp(MIN_SENSE, MAX_SENSE);

    let lua = format!("hl.device({{ name = \"{DEVICE_NAME}\", sensitivity = {new_sense:.2} }})");
    match hypr_eval(&lua) {
        Ok(reply) if reply.trim() == "ok" => {
            if let Some(state) = &state {
                let _ = fs::write(state, format!("{new_sense:.2}\n"));
            }
        }
        Ok(reply) => {
            eprintln!("hyprland rejected sensitivity change: {}", reply.trim());
            exit(1);
        }
        Err(e) => {
            eprintln!("could not reach hyprland: {e}");
            exit(1);
        }
    }

    let percent_str = format_percent(100.0 * (new_sense + 1.0) / 2.0);
    let _ = Command::new("dunstify")
        .args([
            "-h",
            "string:x-dunst-stack-tag:mouse_sensitivity",
            "-h",
            &format!("int:value:{percent_str}"),
            "--",
            &format!(" 󰇀 {percent_str}"),
        ])
        .status();
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_device_block() {
        let cfg = r#"
hl.device({
	name = "tpps/2-elan-trackpoint",
	sensitivity = -0.4,
})
hl.device({
	name = "elecom-shellpha",
	sensitivity = -0.6,
})
"#;
        assert_eq!(sensitivity_from_config(cfg), Some(-0.6));
    }

    #[test]
    fn missing_sensitivity_is_none() {
        let cfg = r#"hl.device({ name = "elecom-shellpha", enabled = true })"#;
        assert_eq!(sensitivity_from_config(cfg), None);
    }
}

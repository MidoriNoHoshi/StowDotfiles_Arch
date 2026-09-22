use std::env;
use std::process::{exit, Command};

const ADDITION: f64 = 0.1;
const MAX_SENSE: f64 = 1.0;
const MIN_SENSE: f64 = -1.0;

const DEVICE_NAME: &str = "elecom-shellpha";

fn extract_float_field(json: &str, key: &str) -> Option<f64> {
    let pattern = format!("\"{key}\":");
    let idx = json.find(&pattern)?;
    let after = json[idx + pattern.len()..].trim_start();

    let mut num_str = String::new();
    for c in after.chars() {
        if c.is_ascii_digit() || c == '-' || c == '.' || c == '+' {
            num_str.push(c);
        } else {
            break;
        }
    }
    num_str.parse::<f64>().ok()
}

fn get_current_sensitivity() -> f64 {
    let output = Command::new("hyprctl").args(["-j", "devices"]).output();

    let stdout = match output {
        Ok(out) if out.status.success() => String::from_utf8_lossy(&out.stdout).into_owned(),
        _ => return 0.0,
    };

    let name_pattern = format!("\"{DEVICE_NAME}\"");
    let Some(start) = stdout.find(&name_pattern) else {
        return 0.0;
    };
    let remainder = &stdout[start..];
    let end = remainder.find('}').unwrap_or(remainder.len());

    extract_float_field(&remainder[..end], "sensitivity").unwrap_or(0.0)
}

fn round2(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

/// Mirrors the old script's sed trim: "55.0" -> "55", "57.5" stays "57.5".
fn format_percent(percent: f64) -> String {
    let formatted = format!("{percent:.1}");
    formatted
        .trim_end_matches('0')
        .trim_end_matches('.')
        .to_string()
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let direction = match args.get(1).map(String::as_str) {
        Some("up") => 1.0,
        Some("down") => -1.0,
        _ => exit(1),
    };

    let current = get_current_sensitivity();
    let new_sense = round2(current + direction * ADDITION);
    let final_sense = new_sense.clamp(MIN_SENSE, MAX_SENSE);

    let final_str = format!("{final_sense:.2}");

    let linear_scaling = (final_sense + 1.0) / 2.0;
    let percent_str = format_percent(100.0 * linear_scaling);


    let lua = format!("hl.device({{ name = \"{DEVICE_NAME}\", sensitivity = {final_str} }})");
    let _ = Command::new("hyprctl").args(["eval", &lua]).status();

    let label = format!(" 󰇀 {percent_str}");
    let _ = Command::new("dunstify")
        .args([
            "-h",
            "string:x-dunst-stack-tag:mouse_sensitivity",
            "-h",
            &format!("int:value:{percent_str}"),
            "--",
            &label,
        ])
        .status();

    exit(0);
}

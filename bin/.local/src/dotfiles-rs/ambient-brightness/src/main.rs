//! Ambient-light adaptive backlight, using the webcam as a light meter.
//!
//! /dev/video0 (YUYV) --> mean of Y samples --> L_ambient (0-255)
//!        |
//!        v
//! power/wifi profile (sysfs) --> B_target  [linear map]
//!        |
//!        v
//! EMA low-pass --> B_smoothed --> hysteresis gate --> brightnessctl
//!
//! Idle dimming is left to hypridle. While hypridle has the screen dimmed it
//! creates $XDG_RUNTIME_DIR/ambient-brightness.pause, and this daemon stops
//! touching the camera or backlight until the file is gone again.
//!
//! Usage: ambient-brightness          run as a daemon
//!        ambient-brightness --once   take one reading, set brightness, exit
//!        ambient-brightness --measure print the reading and target, change nothing

use std::env;
use std::fs;
use std::io;
use std::path::PathBuf;
use std::process::{Command, ExitCode};
use std::thread::sleep;
use std::time::Duration;

use v4l::buffer::Type;
use v4l::io::traits::CaptureStream;
use v4l::prelude::*;
use v4l::video::Capture;
use v4l::FourCC;

// --- Sensing ---
const CAMERA_DEVICE: &str = "/dev/video0";
const CAPTURE_WIDTH: u32 = 640;
const CAPTURE_HEIGHT: u32 = 360;
const CAMERA_WARMUP_FRAMES: usize = 2;
const FRAME_TIMEOUT: Duration = Duration::from_secs(3);
/// V4L2_CID_PRIVACY: 1 while the ThinkPad camera shutter is closed.
const V4L2_CID_PRIVACY: u32 = 0x009a_0910;

// --- Brightness mapping profiles (%) ---
const B_MIN_AC: f64 = 80.0;
const B_MAX_AC: f64 = 100.0;
const B_MIN_INDOOR: f64 = 8.0;
const B_MAX_INDOOR: f64 = 75.0;
const B_MIN_OUTDOOR: f64 = 1.0;
const B_MAX_OUTDOOR: f64 = 100.0;
const L_AMBIENT_MAX: f64 = 255.0;

// --- Control loop ---
/// Every poll powers the camera up, so this is the main power knob.
const POLL_INTERVAL: Duration = Duration::from_secs(10);
/// Time constant ~= POLL_INTERVAL / EMA_ALPHA (~29 s).
const EMA_ALPHA: f64 = 0.35;
const HYSTERESIS_DELTA_PCT: f64 = 12.0;

const AC_ONLINE_PATH: &str = "/sys/class/power_supply/AC/online";

fn pause_flag() -> PathBuf {
    let runtime = env::var_os("XDG_RUNTIME_DIR").unwrap_or_else(|| "/tmp".into());
    PathBuf::from(runtime).join("ambient-brightness.pause")
}

fn camera_shutter_closed(dev: &Device) -> bool {
    matches!(
        dev.control(V4L2_CID_PRIVACY).map(|c| c.value),
        Ok(v4l::control::Value::Boolean(true)) | Ok(v4l::control::Value::Integer(1))
    )
}

/// Grab one frame and return its mean luma, or None if the shutter is closed.
fn capture_ambient_luminance() -> io::Result<Option<f64>> {
    let dev = Device::with_path(CAMERA_DEVICE)?;
    if camera_shutter_closed(&dev) {
        return Ok(None);
    }

    let mut fmt = dev.format()?;
    fmt.width = CAPTURE_WIDTH;
    fmt.height = CAPTURE_HEIGHT;
    fmt.fourcc = FourCC::new(b"YUYV");
    let fmt = dev.set_format(&fmt)?;
    if fmt.fourcc != FourCC::new(b"YUYV") {
        return Err(io::Error::other(format!("camera refused YUYV (got {})", fmt.fourcc)));
    }

    let mut stream = MmapStream::with_buffers(&dev, Type::VideoCapture, 2)?;
    stream.set_timeout(FRAME_TIMEOUT);
    // Let auto-exposure settle a little before measuring.
    for _ in 0..CAMERA_WARMUP_FRAMES {
        stream.next()?;
    }
    let (buf, meta) = stream.next()?;
    let data = &buf[..(meta.bytesused as usize).min(buf.len())];

    // YUYV packs Y0 U Y1 V, so luma is every even byte.
    let (sum, n) = data
        .iter()
        .step_by(2)
        .fold((0u64, 0u64), |(s, n), &y| (s + y as u64, n + 1));
    if n == 0 {
        return Err(io::Error::other("empty frame"));
    }
    // Y is limited range (16-235); expand to 0-255 like OpenCV's BGR->gray
    // did in the old Python daemon, so the profile tuning carries over.
    let y_mean = sum as f64 / n as f64;
    Ok(Some(((y_mean - 16.0) * 255.0 / 219.0).clamp(0.0, 255.0)))
}

fn is_ac_powered() -> bool {
    fs::read_to_string(AC_ONLINE_PATH).is_ok_and(|s| s.trim() == "1")
}

/// Any wlan* interface that is associated counts as "indoors".
fn is_connected_to_wifi() -> bool {
    let Ok(entries) = fs::read_dir("/sys/class/net") else {
        return false;
    };
    entries.flatten().any(|e| {
        e.file_name().to_string_lossy().starts_with("wlan")
            && fs::read_to_string(e.path().join("operstate")).is_ok_and(|s| s.trim() == "up")
    })
}

fn map_luminance_to_target(l_ambient: f64) -> f64 {
    let (b_min, b_max) = if is_ac_powered() {
        (B_MIN_AC, B_MAX_AC)
    } else if is_connected_to_wifi() {
        (B_MIN_INDOOR, B_MAX_INDOOR)
    } else {
        (B_MIN_OUTDOOR, B_MAX_OUTDOOR)
    };
    let l = l_ambient.clamp(0.0, L_AMBIENT_MAX);
    b_min + (b_max - b_min) * (l / L_AMBIENT_MAX)
}

fn write_brightness(pct: f64) {
    let pct = pct.clamp(0.0, 100.0).round() as u32;
    match Command::new("brightnessctl")
        .args(["-q", "set", &format!("{pct}%")])
        .status()
    {
        Ok(s) if s.success() => println!("brightness set to {pct}%"),
        Ok(s) => eprintln!("brightnessctl exited with {s}"),
        Err(e) => eprintln!("failed to run brightnessctl: {e}"),
    }
}

fn run_once() -> ExitCode {
    match capture_ambient_luminance() {
        Ok(Some(l)) => {
            write_brightness(map_luminance_to_target(l));
            ExitCode::SUCCESS
        }
        Ok(None) => {
            eprintln!("camera shutter closed, leaving brightness alone");
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("capture failed: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run_daemon() -> ExitCode {
    println!("ambient brightness daemon starting");
    let pause = pause_flag();
    let mut smoothed: Option<f64> = None;
    let mut last_written: Option<f64> = None;
    let mut last_l_ambient = 128.0;
    let mut paused = false;

    loop {
        if pause.exists() {
            if !paused {
                println!("paused (screen dimmed by hypridle)");
                paused = true;
            }
            sleep(POLL_INTERVAL);
            continue;
        }
        if paused {
            println!("resumed");
            paused = false;
            // hypridle restores the pre-dim level; re-assert ours on this pass.
            last_written = None;
        }

        match capture_ambient_luminance() {
            Ok(Some(l)) => last_l_ambient = l,
            Ok(None) => {} // shutter closed: hold the last reading
            Err(e) => eprintln!("capture failed: {e}"),
        }

        let target = map_luminance_to_target(last_l_ambient);
        let s = match smoothed {
            None => target,
            Some(prev) => EMA_ALPHA * target + (1.0 - EMA_ALPHA) * prev,
        };
        smoothed = Some(s);

        if last_written.is_none_or(|w| (s - w).abs() >= HYSTERESIS_DELTA_PCT) {
            write_brightness(s);
            last_written = Some(s);
        }

        sleep(POLL_INTERVAL);
    }
}

fn run_measure() -> ExitCode {
    match capture_ambient_luminance() {
        Ok(Some(l)) => {
            println!("L_ambient={l:.1} target={:.1}%", map_luminance_to_target(l));
            ExitCode::SUCCESS
        }
        Ok(None) => {
            println!("camera shutter closed");
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("capture failed: {e}");
            ExitCode::FAILURE
        }
    }
}

fn main() -> ExitCode {
    match env::args().nth(1).as_deref() {
        Some("--once") => run_once(),
        Some("--measure") => run_measure(),
        _ => run_daemon(),
    }
}

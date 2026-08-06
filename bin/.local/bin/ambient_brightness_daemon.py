#!/usr/bin/env python3
"""
/dev/video0 --> grayscale --> Gaussian blur --> spatial average
     (frame)                 (denoise)          (L_ambient scalar, 0-255)
                                                        |
                                                        v
                   iwctl (known SSID?) --> is_indoor flag
                                                        |
                                                        v
                   L_ambient, is_indoor --> B_target(t)  [static mapping]
                                                        |
                                                        v
                   EMA low-pass filter  --> B_smoothed(t) [temporal damping]
                                                        |
                                                        v
                   idle-time state machine --> B_effective(t) [eco floor]
                                                        |
                                                        v
                   hysteresis / deadband gate --> write to brightnessctl
                                                        |
                                                        v
                                                physical backlight
"""

import os
import sys
import time
import signal
import logging
import subprocess
from dataclasses import dataclass
from typing import Optional
import numpy as np
import cv2

# --- Sensing & Processing Config ---
CAMERA_DEVICE = "/dev/video0"
CAPTURE_WIDTH = 320
CAPTURE_HEIGHT = 240
CAMERA_WARMUP_FRAMES = 2
CAMERA_OPEN_TIMEOUT_SEC = 3.0

GAUSSIAN_KERNEL_SIZE = (9, 9)
GAUSSIAN_SIGMA = 0

# --- Brightness Mapping Profiles (%) ---
B_MIN_INDOOR_POWERED = 80.0
B_MAX_INDOOR_POWERED = 100.0

B_MIN_INDOOR = 8.0
B_MAX_INDOOR = 75.0

B_MIN_OUTDOOR = 1.0
B_MAX_OUTDOOR = 100.0

L_AMBIENT_MAX = 255.0

# --- Control Loop Tuning ---
EMA_ALPHA = 0.20
HYSTERESIS_DELTA_PCT = 12.0

IDLE_TIMEOUT_SEC = 120
IDLE_RAMP_DURATION_SEC = 8.0
IDLE_RAMP_STEPS = 16
B_IDLE_FLOOR_PCT = 5.0
IDLE_POLL_INTERVAL_SEC = 1.0

POLL_INTERVAL_SEC = 5.0

IWCTL_INTERFACE = "wlan0"
IWCTL_TIMEOUT_SEC = 2.0
BATTERY_STATUS_PATH = "/sys/class/power_supply/BAT0/status"

BRIGHTNESSCTL_BIN = "brightnessctl"
BRIGHTNESSCTL_DEVICE = None

LOG_LEVEL = logging.INFO
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"

logging.basicConfig(level=LOG_LEVEL, format=LOG_FORMAT, stream=sys.stdout)
log = logging.getLogger("ambient-brightness-daemon")


class ShutdownRequested(Exception):
    """Signal handler exception for clean exits."""

    pass


def _signal_handler(signum, _frame):
    log.info("Received signal %s, shutting down.", signum)
    raise ShutdownRequested()


def capture_ambient_luminance() -> Optional[float]:
    """Capture a single frame from video device and calculate mean luminance."""
    cap = None
    try:
        cap = cv2.VideoCapture(CAMERA_DEVICE, cv2.CAP_V4L2)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAPTURE_WIDTH)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAPTURE_HEIGHT)

        t_start = time.monotonic()
        while not cap.isOpened():
            if time.monotonic() - t_start > CAMERA_OPEN_TIMEOUT_SEC:
                log.warning("Camera open timeout.")
                return None
            time.sleep(0.05)

        frame = None
        for _ in range(CAMERA_WARMUP_FRAMES + 1):
            ok, frame = cap.read()
            if not ok:
                log.warning("Frame capture failed.")
                return None

        return compute_luminance_from_frame(frame)
    except cv2.error as e:
        log.warning("OpenCV capture error: %s", e)
        return None
    finally:
        if cap is not None:
            cap.release()


def compute_luminance_from_frame(frame_bgr: np.ndarray) -> float:
    """Convert BGR to grayscale, apply Gaussian blur, return mean pixel scalar."""
    gray = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, GAUSSIAN_KERNEL_SIZE, sigmaX=GAUSSIAN_SIGMA)
    return float(np.mean(blurred))


def is_connected_to_wifi() -> bool:
    """Check if the wireless interface is currently connected to any network."""
    try:
        result = subprocess.run(
            ["iwctl", "station", IWCTL_INTERFACE, "show"],
            capture_output=True,
            text=True,
            timeout=IWCTL_TIMEOUT_SEC,
        )
        if result.returncode != 0:
            return False
        return "state: connected" in result.stdout.lower()
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        log.debug("iwctl check failed: %s", e)
        return False


def is_ac_powered() -> bool:
    """
    Check if laptop is running on AC power directly bypassing battery charging
    ('Not charging' or 'Unknown' in /sys/class/power_supply/BAT0/status).
    """
    if not os.path.exists(BATTERY_STATUS_PATH):
        return False
    try:
        with open(BATTERY_STATUS_PATH, "r") as f:
            status = f.read().strip().lower()
            # Status is 'not charging' or 'unknown' when power is supplied via AC bypassing battery
            return status in ("not charging", "unknown")
    except OSError as e:
        log.debug("Failed reading battery status: %s", e)
        return False


def map_luminance_to_target_brightness(l_ambient: float) -> float:
    """Linear interpolation of luminance to target percentage across 3 power profiles."""
    if is_ac_powered():
        b_min, b_max = B_MIN_INDOOR_POWERED, B_MAX_INDOOR_POWERED
        profile = "indoor_powered"
    elif is_connected_to_wifi():
        b_min, b_max = B_MIN_INDOOR, B_MAX_INDOOR
        profile = "indoor"
    else:
        b_min, b_max = B_MIN_OUTDOOR, B_MAX_OUTDOOR
        profile = "outdoor"

    l_clamped = max(0.0, min(L_AMBIENT_MAX, l_ambient))
    b_target = b_min + (b_max - b_min) * (l_clamped / L_AMBIENT_MAX)
    log.debug(
        "Mapped L_ambient=%.1f under profile '%s' -> B_target=%.1f%%",
        l_ambient,
        profile,
        b_target,
    )
    return b_target


def ema_update(
    previous_smoothed: Optional[float], new_target: float, alpha: float = EMA_ALPHA
) -> float:
    """Apply exponential moving average filter to smooth brightness transitions."""
    if previous_smoothed is None:
        return new_target
    return alpha * new_target + (1.0 - alpha) * previous_smoothed


def get_system_idle_seconds() -> Optional[float]:
    """Query loginctl for session idle duration in seconds."""
    try:
        session_id = subprocess.run(
            [
                "loginctl",
                "show-user",
                os.environ.get("USER", ""),
                "-p",
                "Display",
                "--value",
            ],
            capture_output=True,
            text=True,
            timeout=2.0,
        ).stdout.strip()

        if not session_id:
            session_id = subprocess.run(
                ["loginctl", "show-session", "self", "-p", "IdleSinceHint", "--value"],
                capture_output=True,
                text=True,
                timeout=2.0,
            ).stdout.strip()

        idle_since_usec = subprocess.run(
            ["loginctl", "show-session", session_id, "-p", "IdleSinceHint", "--value"],
            capture_output=True,
            text=True,
            timeout=2.0,
        ).stdout.strip()

        idle_hint = subprocess.run(
            ["loginctl", "show-session", session_id, "-p", "IdleHint", "--value"],
            capture_output=True,
            text=True,
            timeout=2.0,
        ).stdout.strip()

        if idle_hint != "yes" or not idle_since_usec or idle_since_usec == "0":
            return 0.0

        return max(0.0, time.time() - (int(idle_since_usec) / 1_000_000.0))
    except (subprocess.TimeoutExpired, FileNotFoundError, ValueError, OSError) as e:
        log.debug("Failed querying idle time: %s", e)
        return None


@dataclass
class IdleRampState:
    """Manages active -> ramping -> idle state transitions for screen dimming."""

    state: str = "ACTIVE"
    ramp_start_time: Optional[float] = None
    ramp_start_brightness: float = 0.0
    last_active_target: float = 50.0

    def update(self, idle_seconds: Optional[float], ambient_target: float) -> float:
        now = time.monotonic()

        if idle_seconds is None or idle_seconds < IDLE_TIMEOUT_SEC:
            if self.state != "ACTIVE":
                log.info("Activity detected -- restoring display brightness.")
            self.state = "ACTIVE"
            self.last_active_target = ambient_target
            return ambient_target

        if self.state == "ACTIVE":
            self.state = "RAMPING"
            self.ramp_start_time = now
            self.ramp_start_brightness = self.last_active_target
            log.info("Idle timeout triggered (%.0fs) -- dimming.", idle_seconds)

        if self.state == "RAMPING":
            elapsed = now - self.ramp_start_time
            progress = min(1.0, elapsed / IDLE_RAMP_DURATION_SEC)
            stepped_progress = round(progress * IDLE_RAMP_STEPS) / IDLE_RAMP_STEPS
            value = (
                self.ramp_start_brightness
                + (B_IDLE_FLOOR_PCT - self.ramp_start_brightness) * stepped_progress
            )
            if progress >= 1.0:
                self.state = "IDLE"
                log.info("Holding at idle floor (%.1f%%).", B_IDLE_FLOOR_PCT)
            return value

        return B_IDLE_FLOOR_PCT


def apply_brightness_if_needed(
    candidate_pct: float, last_written_pct: Optional[float], force: bool = False
) -> Optional[float]:
    """Write brightness value via brightnessctl if hysteresis deadband threshold is met."""
    candidate_pct = max(0.0, min(100.0, candidate_pct))

    if last_written_pct is None:
        write_brightness(candidate_pct)
        return candidate_pct

    delta = abs(candidate_pct - last_written_pct)
    if force or delta >= HYSTERESIS_DELTA_PCT:
        write_brightness(candidate_pct)
        return candidate_pct

    return last_written_pct


def write_brightness(pct: float) -> None:
    """Execute brightnessctl command."""
    pct_int = int(round(pct))
    cmd = [BRIGHTNESSCTL_BIN]
    if BRIGHTNESSCTL_DEVICE:
        cmd += ["--device", BRIGHTNESSCTL_DEVICE]
    cmd += ["set", f"{pct_int}%"]

    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=3.0, check=True)
        log.info("Brightness set to %d%%.", pct_int)
    except (
        FileNotFoundError,
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
    ) as e:
        log.error("Failed writing brightness: %s", e)


def execute_single_pass() -> None:
    """Run a single brightness assessment and update cycle."""
    l_ambient = capture_ambient_luminance()
    if l_ambient is not None:
        b_target = map_luminance_to_target_brightness(l_ambient)
        write_brightness(b_target)


def main() -> int:
    signal.signal(signal.SIGTERM, _signal_handler)
    signal.signal(signal.SIGINT, _signal_handler)

    log.info("Ambient brightness daemon starting.")

    smoothed_brightness: Optional[float] = None
    last_written_pct: Optional[float] = None
    last_l_ambient: float = 128.0
    idle_state = IdleRampState()
    next_ambient_poll = 0.0

    try:
        while True:
            loop_start = time.monotonic()

            if loop_start >= next_ambient_poll:
                l_ambient = capture_ambient_luminance()
                if l_ambient is None:
                    l_ambient = last_l_ambient
                else:
                    last_l_ambient = l_ambient

                b_target = map_luminance_to_target_brightness(l_ambient)
                smoothed_brightness = ema_update(smoothed_brightness, b_target)
                next_ambient_poll = loop_start + POLL_INTERVAL_SEC

            idle_seconds = get_system_idle_seconds()
            was_idle = idle_state.state != "ACTIVE"
            effective_target = idle_state.update(
                idle_seconds, smoothed_brightness or 0.0
            )
            just_restored = was_idle and idle_state.state == "ACTIVE"

            last_written_pct = apply_brightness_if_needed(
                effective_target,
                last_written_pct,
                force=just_restored,
            )

            elapsed = time.monotonic() - loop_start
            time.sleep(max(0.0, IDLE_POLL_INTERVAL_SEC - elapsed))

    except ShutdownRequested:
        log.info("Daemon stopped cleanly.")
        return 0
    except Exception:
        log.exception("Unhandled error in daemon loop.")
        return 1


if __name__ == "__main__":
    if "--trigger" in sys.argv:
        execute_single_pass()
        sys.exit(0)
    else:
        sys.exit(main())

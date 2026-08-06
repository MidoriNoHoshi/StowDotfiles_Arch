#!/usr/bin/env python3
"""
ambient_brightness_daemon.py
=============================================================================
Adaptive ambient-light display brightness daemon for Arch Linux + Hyprland.

PIPELINE OVERVIEW
------------------
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

Every stage is deliberately isolated into its own function so each piece of
control theory (filtering, hysteresis, ramping) can be reasoned about,
tuned, and defended independently.

Author: Senior Embedded/Linux Performance Engineering exercise
License: MIT (do whatever you want with it)
=============================================================================
"""

import os
import sys
import time
import signal
import logging
import subprocess
from dataclasses import dataclass, field
from typing import Optional, List, Tuple

# cv2/numpy are the only non-stdlib deps. Imported after the config block
# conceptually, but Python needs them up top -- see requirements in README.
import numpy as np
import cv2

# =============================================================================
# CONFIGURATION PARAMETERS
# -----------------------------------------------------------------------------
# Every tunable constant lives here. Nothing below this block should contain
# a "magic number" -- if you find one, it's a bug, promote it to this section.
# =============================================================================

# --- Camera / sensing -------------------------------------------------------
CAMERA_DEVICE           = "/dev/video0"   # V4L2 device node for the internal cam
CAPTURE_WIDTH           = 320             # Low res is intentional: we only need
CAPTURE_HEIGHT          = 240             #   a single luminance scalar, not a
                                           #   usable photo. Small frames = less
                                           #   USB/ISP power draw and faster
                                           #   grayscale/blur math.
CAMERA_WARMUP_FRAMES    = 2               # Many UVC webcams return a garbage /
                                           #   under-exposed first frame while
                                           #   auto-exposure settles. We grab
                                           #   and discard a couple of frames
                                           #   before trusting one.
CAMERA_OPEN_TIMEOUT_SEC = 3.0             # Max time to wait for cap.isOpened()

# --- Image processing (ambient luminance estimation) -----------------------
GAUSSIAN_KERNEL_SIZE    = (9, 9)          # Must be odd x odd. Larger kernel =
                                           #   stronger low-pass spatial filter
                                           #   = more immune to sensor shot
                                           #   noise and JPEG/YUV macroblocking,
                                           #   at the cost of more compute.
GAUSSIAN_SIGMA          = 0               # 0 => OpenCV derives sigma from the
                                           #   kernel size automatically
                                           #   (sigma = 0.3*((ksize-1)*0.5-1)+0.8)

# --- Ambient-light -> brightness mapping ------------------------------------
# We keep two separate linear ranges: a tighter one for "indoors" (assumed to
# be on Wi-Fi at a known/trusted network -- e.g. home or office, where high
# peak brightness is rarely needed and every watt saved matters on battery),
# and a wider one for "outdoors/unknown network" where ambient light (and the
# need to overcome glare) can be much higher.
B_MIN_INDOOR            = 8.0             # % brightness floor indoors
B_MAX_INDOOR            = 55.0            # % brightness ceiling indoors
B_MIN_OUTDOOR           = 15.0            # % brightness floor outdoors/unknown
B_MAX_OUTDOOR           = 100.0           # % brightness ceiling outdoors/unknown
L_AMBIENT_MAX           = 255.0           # Theoretical max of an 8-bit gray pixel

# --- Low-pass filter (EMA) --------------------------------------------------
# B_smoothed[t] = ALPHA * B_target[t] + (1 - ALPHA) * B_smoothed[t-1]
#
# ALPHA in (0, 1]. It is the fraction of the *new* sample that is allowed to
# influence the filter output on each tick.
#   ALPHA -> 1   : no filtering, B_smoothed tracks B_target instantly
#                  (reacts to every flicker/shadow -- bad, causes flicker)
#   ALPHA -> 0   : infinite damping, B_smoothed never moves
#                  (unresponsive -- bad, ignores real light changes)
# The filter has an exponential step response with time constant
#   tau = -POLL_INTERVAL_SEC / ln(1 - ALPHA)
# i.e. with ALPHA=0.2 and a 5s poll interval, tau ~= 22.4s: a step change in
# ambient light reaches ~63% of its new steady-state value in ~22s. This is
# intentionally slow -- we want to smooth out someone briefly walking past a
# window, not create visible display "breathing".
EMA_ALPHA               = 0.20

# --- Hysteresis / deadband ---------------------------------------------------
# We only physically write a new brightness value to the backlight if the
# smoothed target has drifted from the *last written* value by at least
# this many percentage points. Without this, a filtered signal that is
# oscillating by +/-0.4% around a threshold would still cause the backlight
# driver to be written every poll cycle, which is wasted syscalls/PWM
# reprogramming and, on some panels, visible micro-flicker.
HYSTERESIS_DELTA_PCT    = 3.0

# --- Idle / activity-based dimming ------------------------------------------
IDLE_TIMEOUT_SEC        = 120             # No input for this long => start dimming
IDLE_RAMP_DURATION_SEC  = 8.0             # Time to smoothly ramp DOWN to floor
IDLE_RAMP_STEPS         = 16              # Number of intermediate steps in the
                                           #   down-ramp (higher = smoother, more
                                           #   writes)
B_IDLE_FLOOR_PCT        = 5.0             # Eco floor brightness while idle
IDLE_POLL_INTERVAL_SEC  = 1.0             # loginctl idle-hint is cheap; poll fast
                                           #   so "restore instantly on activity"
                                           #   actually feels instant.

# --- Main loop timing --------------------------------------------------------
POLL_INTERVAL_SEC       = 5.0             # Ambient-light sensing cadence.
                                           #   Camera is opened, sampled, and
                                           #   released fully within each tick
                                           #   -- see release_camera_between_polls.

# --- Network / location heuristic -------------------------------------------
IWCTL_INTERFACE         = "wlan0"
KNOWN_SSIDS: List[str]  = [
    "HomeNet-5G",
    "OfficeWiFi",
    # Add your trusted / "indoors" SSIDs here.
]
IWCTL_TIMEOUT_SEC       = 2.0

# --- brightnessctl integration ----------------------------------------------
BRIGHTNESSCTL_BIN       = "brightnessctl"
BRIGHTNESSCTL_DEVICE    = None            # None => let brightnessctl auto-select
                                           #   the default backlight class device.
                                           #   Set e.g. "intel_backlight" to pin it.

# --- Logging -----------------------------------------------------------------
LOG_LEVEL               = logging.INFO
LOG_FORMAT              = "%(asctime)s [%(levelname)s] %(message)s"

# =============================================================================
# END CONFIGURATION PARAMETERS
# =============================================================================


logging.basicConfig(level=LOG_LEVEL, format=LOG_FORMAT, stream=sys.stdout)
log = logging.getLogger("ambient-brightness-daemon")


# -----------------------------------------------------------------------------
# Graceful shutdown plumbing
# -----------------------------------------------------------------------------
class ShutdownRequested(Exception):
    """Raised internally when SIGTERM/SIGINT is received, to unwind cleanly
    out of the main loop (and, importantly, out of any camera context)."""
    pass


def _signal_handler(signum, _frame):
    log.info("Received signal %s, shutting down gracefully...", signum)
    raise ShutdownRequested()


# -----------------------------------------------------------------------------
# STAGE 1: Ambient luminance capture
# -----------------------------------------------------------------------------
def capture_ambient_luminance() -> Optional[float]:
    """
    Open the webcam, grab a frame, compute a single scalar ambient-luminance
    value in [0, 255], and *fully release the device* before returning.

    Releasing the camera between polls matters for two reasons:
      1. Power: an open V4L2 capture session keeps the camera's ISP/sensor
         powered and, on many laptops, keeps a USB device out of suspend,
         which is a direct battery drain that runs contrary to the entire
         point of this daemon.
      2. Cooperation: it avoids holding an exclusive lock on /dev/video0,
         so video-conferencing apps etc. aren't blocked from using the
         camera in between our (sub-second) polls.

    Returns None on any failure so the caller can fall back to the last
    known-good luminance rather than crash the daemon over a flaky camera.
    """
    cap = None
    try:
        cap = cv2.VideoCapture(CAMERA_DEVICE, cv2.CAP_V4L2)

        # Request a small capture resolution. This is a *request*; not all
        # UVC devices honor it exactly, but it steers the driver toward a
        # cheaper mode and avoids us doing unnecessary downsampling work on
        # a full 1080p frame just to average it into one number.
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, CAPTURE_WIDTH)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, CAPTURE_HEIGHT)

        t_start = time.monotonic()
        while not cap.isOpened():
            if time.monotonic() - t_start > CAMERA_OPEN_TIMEOUT_SEC:
                log.warning("Camera did not open within timeout, skipping cycle.")
                return None
            time.sleep(0.05)

        # Discard the first N frames: auto-exposure/auto-gain on most UVC
        # webcams has not converged yet on frame 0, so its brightness is not
        # representative of the actual ambient scene.
        frame = None
        for _ in range(CAMERA_WARMUP_FRAMES + 1):
            ok, frame = cap.read()
            if not ok:
                log.warning("Frame grab failed, skipping cycle.")
                return None

        return compute_luminance_from_frame(frame)

    except cv2.error as e:
        log.warning("OpenCV error during capture: %s", e)
        return None
    finally:
        # This is the critical "release camera between polling intervals"
        # requirement: whether we succeeded, failed, or raised, the capture
        # handle is torn down here before this function returns, freeing
        # the device node and powering the sensor path back down.
        if cap is not None:
            cap.release()


def compute_luminance_from_frame(frame_bgr: np.ndarray) -> float:
    """
    Convert a BGR frame into a single scalar ambient-luminance estimate.

    Step-by-step control/signal-processing rationale:

      1. Grayscale conversion (BGR -> Y):
         We don't care about color, only luminance, so we collapse 3
         channels into 1 via OpenCV's standard luma-weighted conversion
         (Y = 0.299R + 0.587G + 0.114B). This throws away 2/3 of the data
         we don't need and speeds up every subsequent step 3x.

      2. Gaussian blur (spatial low-pass filter):
         A camera sensor has per-pixel shot noise and, in low light, banding
         from AGC (automatic gain control). If we just took a naive mean of
         raw pixels this noise mostly cancels out anyway over a full frame,
         BUT blurring first also suppresses *localized* high-frequency
         artifacts (e.g. a single blown-out reflection, a thin light beam
         from a doorway) from disproportionately swinging small regional
         averages if we ever want to do more than a single global mean in
         the future (e.g. zone-weighted metering). Conceptually this is a
         2D convolution with a Gaussian kernel:
             blurred(x,y) = sum_{i,j} G(i,j) * gray(x+i, y+j)
         where G is a normalized Gaussian: closer neighboring pixels get
         more weight, distant ones less, giving a smooth spatial average
         rather than a hard box filter (which would introduce ringing).

      3. Spatial averaging / downsampling to one scalar:
         The mean of the blurred grayscale image is our ambient luminance
         estimate. This is mathematically equivalent to "downsampling" the
         image all the way down to a 1x1 pixel via area-based decimation --
         we just compute it directly as an arithmetic mean for efficiency
         rather than calling cv2.resize down to (1,1).

    Returns a float in [0, 255].
    """
    gray = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2GRAY)

    blurred = cv2.GaussianBlur(
        gray,
        GAUSSIAN_KERNEL_SIZE,
        sigmaX=GAUSSIAN_SIGMA,
    )

    # Global spatial average == "downsample to a single scalar".
    l_ambient = float(np.mean(blurred))
    return l_ambient


# -----------------------------------------------------------------------------
# STAGE 2: Network / location heuristic (indoor vs outdoor assumption)
# -----------------------------------------------------------------------------
def is_connected_to_known_network() -> bool:
    """
    Query iwd via `iwctl station <iface> show` and check whether we're
    associated with an SSID in KNOWN_SSIDS.

    We treat "on a known/trusted Wi-Fi network" as a cheap proxy for
    "indoors", which lets us cap peak brightness lower (offices/homes rarely
    need 100% panel brightness, and capping it saves real power on OLED/LCD
    backlights) without needing GPS or ambient-light-sensor-grade location
    data.

    Any failure (iwd not running, interface down, iwctl missing, timeout)
    is treated as "unknown" -> we fall back to the wider/outdoor mapping
    range, which is the safer default (better to risk being slightly too
    bright than too dim to read the screen).
    """
    try:
        result = subprocess.run(
            ["iwctl", "station", IWCTL_INTERFACE, "show"],
            capture_output=True,
            text=True,
            timeout=IWCTL_TIMEOUT_SEC,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        log.debug("iwctl query failed (%s); assuming outdoor/unknown network.", e)
        return False

    if result.returncode != 0:
        log.debug("iwctl returned nonzero exit status; assuming unknown network.")
        return False

    output = result.stdout
    # Typical relevant line looks like:
    #   Connected network         HomeNet-5G
    for line in output.splitlines():
        line = line.strip()
        if line.lower().startswith("connected network"):
            # Everything after the label is the SSID (iwctl right-pads/aligns
            # with whitespace, so split on runs of whitespace).
            parts = line.split(maxsplit=2)
            if len(parts) >= 3:
                ssid = parts[2].strip()
                if ssid in KNOWN_SSIDS:
                    log.debug("Connected to known SSID '%s' -> indoor.", ssid)
                    return True
                else:
                    log.debug("Connected to unrecognized SSID '%s' -> outdoor/unknown.", ssid)
                    return False

    return False


# -----------------------------------------------------------------------------
# STAGE 3: Static ambient-light -> target-brightness mapping
# -----------------------------------------------------------------------------
def map_luminance_to_target_brightness(l_ambient: float, is_indoor: bool) -> float:
    """
    Linear mapping from ambient luminance L_ambient in [0, 255] to a target
    brightness percentage B_target, using a narrower range indoors and a
    wider range outdoors:

        B_target = B_min + (B_max - B_min) * (L_ambient / L_AMBIENT_MAX)

    This is intentionally a *simple linear map* rather than e.g. a gamma
    curve: the EMA filter downstream already provides all the temporal
    smoothing we need, and keeping this stage purely algebraic makes the
    whole pipeline easy to reason about and unit-test in isolation.
    """
    if is_indoor:
        b_min, b_max = B_MIN_INDOOR, B_MAX_INDOOR
    else:
        b_min, b_max = B_MIN_OUTDOOR, B_MAX_OUTDOOR

    l_clamped = max(0.0, min(L_AMBIENT_MAX, l_ambient))
    b_target = b_min + (b_max - b_min) * (l_clamped / L_AMBIENT_MAX)
    return b_target


# -----------------------------------------------------------------------------
# STAGE 4: Low-pass filter (EMA) -- see CONFIGURATION comments for the math
# -----------------------------------------------------------------------------
def ema_update(previous_smoothed: Optional[float], new_target: float, alpha: float = EMA_ALPHA) -> float:
    """
    One tick of the first-order exponential moving average filter:

        B_smoothed[t] = alpha * B_target[t] + (1 - alpha) * B_smoothed[t-1]

    On the very first call (no history yet), we initialize B_smoothed to
    B_target directly -- otherwise the filter would start at 0 and take
    several time constants to "warm up" to the true value, causing the
    screen to visibly ramp up from black on daemon start.
    """
    if previous_smoothed is None:
        return new_target
    return alpha * new_target + (1.0 - alpha) * previous_smoothed


# -----------------------------------------------------------------------------
# STAGE 5: Idle detection (systemd-logind IdleHint) and idle ramp-down
# -----------------------------------------------------------------------------
def get_system_idle_seconds() -> Optional[float]:
    """
    Ask systemd-logind, via `loginctl`, how long the current graphical
    session has been idle. logind's IdleHint is fed by the compositor
    (Hyprland reports idle state over its idle-notify Wayland protocol, the
    same signal hypridle consumes), so this gives us a portable,
    dependency-light way to read "no keyboard/mouse activity" without
    talking to Wayland protocols directly or polling /dev/input (which
    would require elevated privileges/udev rules).

    Returns idle duration in seconds, or None if it can't be determined
    (in which case the caller should assume "active" as the safe default,
    i.e. never dim if we're not sure).
    """
    try:
        # Resolve the current session ID first.
        session_id = subprocess.run(
            ["loginctl", "show-user", os.environ.get("USER", ""), "-p", "Display", "--value"],
            capture_output=True, text=True, timeout=2.0,
        ).stdout.strip()

        if not session_id:
            # Fallback: ask for the caller's own active session directly.
            session_id = subprocess.run(
                ["loginctl", "show-session", "self" if _supports_self() else _current_session_id(), "-p", "IdleSinceHint", "--value"],
                capture_output=True, text=True, timeout=2.0,
            ).stdout.strip()

        idle_since_usec = subprocess.run(
            ["loginctl", "show-session", session_id, "-p", "IdleSinceHint", "--value"],
            capture_output=True, text=True, timeout=2.0,
        ).stdout.strip()

        idle_hint = subprocess.run(
            ["loginctl", "show-session", session_id, "-p", "IdleHint", "--value"],
            capture_output=True, text=True, timeout=2.0,
        ).stdout.strip()

        if idle_hint != "yes" or not idle_since_usec or idle_since_usec == "0":
            return 0.0  # Not idle (or logind hasn't set a since-timestamp yet).

        idle_since_sec = int(idle_since_usec) / 1_000_000.0
        now_sec = time.time()
        return max(0.0, now_sec - idle_since_sec)

    except (subprocess.TimeoutExpired, FileNotFoundError, ValueError, OSError) as e:
        log.debug("Could not determine idle time via loginctl (%s).", e)
        return None


def _supports_self() -> bool:
    # Newer systemd supports `loginctl show-session self`; older ones don't.
    # We probe once lazily; cheap enough to just try/except at call sites in
    # practice, but kept here for readability of get_system_idle_seconds().
    return True


def _current_session_id() -> str:
    try:
        return subprocess.run(
            ["loginctl", "list-sessions", "--no-legend"],
            capture_output=True, text=True, timeout=2.0,
        ).stdout.split()[0]
    except Exception:
        return ""


@dataclass
class IdleRampState:
    """
    Tiny state machine for the idle -> eco-floor ramp.

    States:
      ACTIVE   : user is active (or idle < IDLE_TIMEOUT_SEC). Brightness is
                 driven entirely by the ambient-light pipeline.
      RAMPING  : idle timeout just elapsed; we are linearly interpolating
                 from the last active brightness down to B_IDLE_FLOOR_PCT
                 over IDLE_RAMP_DURATION_SEC, in IDLE_RAMP_STEPS steps. This
                 avoids an instant, jarring cut to black.
      IDLE     : fully ramped down and holding at B_IDLE_FLOOR_PCT.

    Transition IDLE/RAMPING -> ACTIVE is immediate (no ramp) per the spec's
    "restore instantly upon input activity" requirement -- there's no reason
    to make the user wait through a fade-in just to see their screen again.
    """
    state: str = "ACTIVE"
    ramp_start_time: Optional[float] = None
    ramp_start_brightness: float = 0.0
    last_active_target: float = 50.0  # last ambient-driven target while active

    def update(self, idle_seconds: Optional[float], ambient_target: float) -> float:
        now = time.monotonic()

        # Unknown idle state -> fail safe to "active" behavior.
        if idle_seconds is None:
            self.state = "ACTIVE"
            self.last_active_target = ambient_target
            return ambient_target

        if idle_seconds < IDLE_TIMEOUT_SEC:
            # User is active (or hasn't been idle long enough to matter).
            if self.state != "ACTIVE":
                log.info("Activity detected -- restoring brightness instantly.")
            self.state = "ACTIVE"
            self.last_active_target = ambient_target
            return ambient_target

        # idle_seconds >= IDLE_TIMEOUT_SEC from here on.
        if self.state == "ACTIVE":
            # Just crossed the idle threshold: begin the down-ramp.
            self.state = "RAMPING"
            self.ramp_start_time = now
            self.ramp_start_brightness = self.last_active_target
            log.info("Idle timeout reached (%.0fs) -- beginning dim ramp.", idle_seconds)

        if self.state == "RAMPING":
            elapsed = now - self.ramp_start_time
            progress = min(1.0, elapsed / IDLE_RAMP_DURATION_SEC)
            # Quantize into IDLE_RAMP_STEPS discrete steps so we don't emit
            # a brightness write on every single poll tick during the ramp
            # -- IDLE_RAMP_STEPS controls the granularity/smoothness
            # trade-off independently of POLL_INTERVAL_SEC.
            stepped_progress = round(progress * IDLE_RAMP_STEPS) / IDLE_RAMP_STEPS
            value = (
                self.ramp_start_brightness
                + (B_IDLE_FLOOR_PCT - self.ramp_start_brightness) * stepped_progress
            )
            if progress >= 1.0:
                self.state = "IDLE"
                log.info("Idle ramp complete -- holding at eco floor (%.1f%%).", B_IDLE_FLOOR_PCT)
            return value

        # state == "IDLE"
        return B_IDLE_FLOOR_PCT


# -----------------------------------------------------------------------------
# STAGE 6: Hysteresis-gated physical write
# -----------------------------------------------------------------------------
def apply_brightness_if_needed(candidate_pct: float, last_written_pct: Optional[float], force: bool = False) -> Optional[float]:
    """
    Hysteresis / deadband gate.

    We only issue a physical brightnessctl write if:
        |candidate_pct - last_written_pct| >= HYSTERESIS_DELTA_PCT
    or if `force` is True (used for the "instant restore on activity" case,
    where we deliberately want to bypass the deadband so the screen snaps
    back immediately rather than waiting for a >= HYSTERESIS_DELTA_PCT swing).

    Why this matters: EMA-filtered signals still creep slowly, and without a
    deadband we'd end up calling brightnessctl every single poll tick as the
    filtered value drifts by fractions of a percent -- unnecessary syscalls,
    unnecessary backlight PWM reprogramming (a real source of flicker/wear
    on some panels), for a change no human eye could perceive.

    Returns the new last_written_pct (unchanged if we decided not to write).
    """
    candidate_pct = max(0.0, min(100.0, candidate_pct))

    if last_written_pct is None:
        write_brightness(candidate_pct)
        return candidate_pct

    delta = abs(candidate_pct - last_written_pct)
    if force or delta >= HYSTERESIS_DELTA_PCT:
        write_brightness(candidate_pct)
        return candidate_pct

    log.debug(
        "Hysteresis gate: candidate=%.1f%% last=%.1f%% delta=%.1f%% < threshold=%.1f%% -- no write.",
        candidate_pct, last_written_pct, delta, HYSTERESIS_DELTA_PCT,
    )
    return last_written_pct


def write_brightness(pct: float) -> None:
    """Issue the actual `brightnessctl set` call."""
    pct_int = int(round(pct))
    cmd = [BRIGHTNESSCTL_BIN]
    if BRIGHTNESSCTL_DEVICE:
        cmd += ["--device", BRIGHTNESSCTL_DEVICE]
    cmd += ["set", f"{pct_int}%"]

    try:
        subprocess.run(cmd, capture_output=True, text=True, timeout=3.0, check=True)
        log.info("Brightness set to %d%%.", pct_int)
    except FileNotFoundError:
        log.error("brightnessctl binary not found. Is it installed and on PATH?")
    except subprocess.CalledProcessError as e:
        log.error("brightnessctl failed (%s): %s", e.returncode, e.stderr.strip())
    except subprocess.TimeoutExpired:
        log.error("brightnessctl call timed out.")


# -----------------------------------------------------------------------------
# Main daemon loop
# -----------------------------------------------------------------------------
def main() -> int:
    signal.signal(signal.SIGTERM, _signal_handler)
    signal.signal(signal.SIGINT, _signal_handler)

    log.info("Ambient brightness daemon starting.")
    log.info(
        "Config: poll=%.1fs alpha=%.2f hysteresis=%.1f%% idle_timeout=%ds idle_floor=%.1f%%",
        POLL_INTERVAL_SEC, EMA_ALPHA, HYSTERESIS_DELTA_PCT, IDLE_TIMEOUT_SEC, B_IDLE_FLOOR_PCT,
    )

    smoothed_brightness: Optional[float] = None
    last_written_pct: Optional[float] = None
    last_l_ambient: float = 128.0  # sane midpoint fallback if camera ever fails
    idle_state = IdleRampState()

    next_ambient_poll = 0.0  # force an immediate first read

    try:
        while True:
            loop_start = time.monotonic()

            # --- Ambient sensing + mapping + EMA run on the slower cadence ---
            if loop_start >= next_ambient_poll:
                l_ambient = capture_ambient_luminance()
                if l_ambient is None:
                    log.debug("Using last known-good luminance (%.1f).", last_l_ambient)
                    l_ambient = last_l_ambient
                else:
                    last_l_ambient = l_ambient

                indoor = is_connected_to_known_network()
                b_target = map_luminance_to_target_brightness(l_ambient, indoor)
                smoothed_brightness = ema_update(smoothed_brightness, b_target)

                log.debug(
                    "L_ambient=%.1f indoor=%s B_target=%.1f%% B_smoothed=%.1f%%",
                    l_ambient, indoor, b_target, smoothed_brightness,
                )

                next_ambient_poll = loop_start + POLL_INTERVAL_SEC

            # --- Idle detection runs on the faster cadence for snappy resume ---
            idle_seconds = get_system_idle_seconds()
            was_idle_or_ramping = idle_state.state != "ACTIVE"
            effective_target = idle_state.update(idle_seconds, smoothed_brightness or 0.0)
            just_became_active = was_idle_or_ramping and idle_state.state == "ACTIVE"

            last_written_pct = apply_brightness_if_needed(
                effective_target,
                last_written_pct,
                force=just_became_active,  # bypass deadband for instant restore
            )

            # Sleep until the next idle-poll tick (the fine-grained cadence);
            # the ambient poll is gated separately above via next_ambient_poll.
            elapsed = time.monotonic() - loop_start
            time.sleep(max(0.0, IDLE_POLL_INTERVAL_SEC - elapsed))

    except ShutdownRequested:
        log.info("Daemon stopped cleanly.")
        return 0
    except Exception:
        log.exception("Unhandled exception in main loop -- exiting.")
        return 1


if __name__ == "__main__":
    sys.exit(main())

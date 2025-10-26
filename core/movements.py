import atexit
import random
import threading
import time
from threading import Lock, Thread

import board
import numpy as np
from adafruit_motorkit import MotorKit

from .config import BILLY_PINS, MOUTH_ARTICULATION, is_classic_billy


# === Configuration ===
USE_THIRD_MOTOR = is_classic_billy()
print(f"⚙️ Using third motor: {USE_THIRD_MOTOR} | Pin profile: {BILLY_PINS}")

# === MotorKit Setup ===
kit = MotorKit(i2c=board.I2C())
print("🔧 MotorKit initialized")

# -------------------------------------------------------------------
# Motor mapping
# -------------------------------------------------------------------
# MotorKit provides 4 motors: motor1, motor2, motor3, motor4
# We map: motor1=mouth, motor2=body, motor3=head
# Note: body is used for tail movement in the current implementation

FLIP_MOUTH_DIRECTION = True
FLIP_HEAD_DIRECTION = False
FLIP_TAIL_DIRECTION = True

# For compatibility with existing code that expects pin numbers
MOUTH = 1
HEAD = 2
TAIL = 3  # Using body motor for tail

if MOUTH == 1:
    MOUTH_MOTOR = kit.motor1
if MOUTH == 2:
    MOUTH_MOTOR = kit.motor2
if MOUTH == 3:
    MOUTH_MOTOR = kit.motor3

if HEAD == 1:
    HEAD_MOTOR = kit.motor1
if HEAD == 2:
    HEAD_MOTOR = kit.motor2
if HEAD == 3:
    HEAD_MOTOR = kit.motor3

if TAIL == 1:
    TAIL_MOTOR = kit.motor1
if TAIL == 2:
    TAIL_MOTOR = kit.motor2
if TAIL == 3:
    TAIL_MOTOR = kit.motor3

# All motor references for tracking
motor_refs = [MOUTH_MOTOR, TAIL_MOTOR, HEAD_MOTOR]
motor_pins = [MOUTH, TAIL, HEAD]  # For compatibility with existing code

# === State ===
_head_tail_lock = Lock()
_motor_watchdog_running = False
_last_flap = 0
_mouth_open_until = 0
_last_rms = 0
head_out = False

# === Throttle tracking (so watchdog can see motor activity) ===
_throttle = {pin: {"throttle": 0, "since": None} for pin in motor_pins}
_motor_map = {MOUTH: MOUTH_MOTOR, TAIL: TAIL_MOTOR, HEAD: HEAD_MOTOR}


def set_throttle(pin: int, throttle: float):
    """Start/adjust throttle on motor and remember when it went active."""
    motor = _motor_map.get(pin)
    if motor is None:
        return

    # Convert percentage to throttle (-1.0 to 1.0)
    throttle_value = max(-1.0, min(1.0, throttle / 100.0))

    # Apply direction flip based on motor type
    if pin == MOUTH and FLIP_MOUTH_DIRECTION:
        throttle_value = -throttle_value
    elif pin == HEAD and FLIP_HEAD_DIRECTION:
        throttle_value = -throttle_value
    elif pin == TAIL and FLIP_TAIL_DIRECTION:
        throttle_value = -throttle_value

    motor.throttle = throttle_value

    if abs(throttle_value) > 0:
        _throttle[pin]["throttle"] = throttle_value
        _throttle[pin]["since"] = (
            time.time() if _throttle[pin]["since"] is None else _throttle[pin]["since"]
        )
    else:
        _throttle[pin]["throttle"] = 0
        _throttle[pin]["since"] = None


def clear_throttle(pin: int):
    """Stop throttle on motor and clear active since timestamp."""
    motor = _motor_map.get(pin)
    if motor is None:
        return

    motor.throttle = 0
    _throttle[pin]["throttle"] = 0
    _throttle[pin]["since"] = None


# === Motor Helpers ===
def brake_motor(pin1, pin2=None):
    """Actively stop the motor: zero throttle."""
    clear_throttle(pin1)
    if pin2 is not None:
        clear_throttle(pin2)


def run_motor_async(motor_pin, low_pin=None, speed_percent=100, duration=0.3, brake=True):
    # MotorKit handles the low pin internally, so we ignore it
    set_throttle(motor_pin, float(speed_percent))
    if brake:
        threading.Timer(duration, lambda: brake_motor(motor_pin, low_pin)).start()
    else:
        # still auto-close after duration, but just clear throttle (no active brake)
        threading.Timer(duration, lambda: clear_throttle(motor_pin)).start()


# === Movement Functions (keep signatures/behavior) ===
def move_mouth(speed_percent, duration, brake=False):
    run_motor_async(MOUTH, None, speed_percent, duration, brake)


def stop_mouth():
    brake_motor(MOUTH, None)


def move_head(state="on"):
    global head_out

    def _move_head_on():
        # Move head to extended position
        set_throttle(HEAD, 80)
        time.sleep(0.5)
        set_throttle(HEAD, 100)  # stay extended

    if state == "on":
        if not head_out:
            threading.Thread(target=_move_head_on, daemon=True).start()
            head_out = True
    else:
        # Stop head motor
        brake_motor(HEAD, None)
        head_out = False


def move_tail(duration=0.2):
    """
    Move tail using the body motor (motor2).
    MotorKit handles the motor control internally.
    """
    run_motor_async(TAIL, None, speed_percent=80, duration=duration)


def move_tail_async(duration=0.3):
    threading.Thread(target=move_tail, args=(duration,), daemon=True).start()


def _articulation_multiplier():
    """Return direct articulation multiplier (1 = normal, higher = slower)."""
    return max(0, min(10, float(MOUTH_ARTICULATION)))


# === Mouth Sync ===
def flap_from_pcm_chunk(
    audio, threshold=1500, min_flap_gap=0.15, chunk_ms=40, sample_rate=24000  # pylint: disable=unused-argument
):
    global _last_flap, _mouth_open_until, _last_rms
    now = time.time()

    if audio.size == 0:
        return

    rms = np.sqrt(np.mean(audio.astype(np.float32) ** 2))
    # peak = np.max(np.abs(audio))  # Not used in current implementation

    # Smooth out sudden fluctuations
    if '_last_rms' not in globals():
        _last_rms = rms
    alpha = 1  # smoothing factor
    rms = alpha * rms + (1 - alpha) * _last_rms
    _last_rms = rms

    # If too quiet and mouth might be open, stop motor
    if rms < threshold / 2 and now >= _mouth_open_until:
        stop_mouth()
        return

    if rms <= threshold or (now - _last_flap) < min_flap_gap:
        return

    normalized = np.clip(rms / 32768.0, 0.0, 1.0)
    # dyn_range = peak / (rms + 1e-5)  # Not used in current implementation

    # Flap speed and duration scaling
    speed = int(np.clip(np.interp(normalized, [0.005, 0.15], [25, 100]), 25, 100))
    duration_ms = np.interp(normalized, [0.005, 0.15], [15, 70])

    duration_ms = np.clip(duration_ms, 15, chunk_ms)
    duration = duration_ms / 1000.0

    duration *= _articulation_multiplier()

    _last_flap = now
    _mouth_open_until = now + duration

    move_mouth(speed, duration, brake=False)


# === Interlude Behavior ===
def _interlude_routine():
    try:
        move_head("off")
        time.sleep(random.uniform(0.2, 2))
        flap_count = random.randint(1, 3)
        for _ in range(flap_count):
            move_tail()
            time.sleep(random.uniform(0.25, 0.9))
        if random.random() < 0.9:
            move_head("on")
    except Exception as e:
        print(f"⚠️ Interlude error: {e}")


def interlude():
    """Run head/tail interlude in a background thread if not already running."""
    if _head_tail_lock.locked():
        return
    Thread(target=lambda: _interlude_routine(), daemon=True).start()


# === Motor Watchdog (per-pin continuous activity) ===
WATCHDOG_TIMEOUT_SEC = 30  # max continuous ON time per pin
WATCHDOG_POLL_SEC = 1.0  # poll cadence


def _mate_for(pin: int):  # pylint: disable=unused-argument
    """
    MotorKit handles motor control internally, so no mate pins needed.
    Return None for all pins.
    """
    return None


def _stop_channel(pin: int):
    """Stop one motor safely."""
    clear_throttle(pin)


def _pin_is_active(pin: int) -> bool:
    """Active if throttle > 0."""
    return abs(_throttle.get(pin, {}).get("throttle", 0)) > 0


def stop_all_motors():
    print("🛑 Stopping all motors")
    for pin in motor_pins:
        clear_throttle(pin)


def is_motor_active():
    return any(_pin_is_active(pin) for pin in motor_pins)


def motor_watchdog():
    """Stop any single pin that stays active longer than WATCHDOG_TIMEOUT_SEC."""
    global _motor_watchdog_running
    _motor_watchdog_running = True

    # Track continuous-on start time per pin
    since_on = {pin: None for pin in motor_pins}

    while _motor_watchdog_running:
        now = time.time()
        for pin in motor_pins:
            active = _pin_is_active(pin)
            if active:
                if since_on[pin] is None:
                    since_on[pin] = now
                else:
                    if (now - since_on[pin]) >= WATCHDOG_TIMEOUT_SEC:
                        print(
                            f"⏱️ Watchdog: pin {pin} active > {WATCHDOG_TIMEOUT_SEC}s → braking channel"
                        )
                        _stop_channel(pin)
                        since_on[pin] = None
            else:
                since_on[pin] = None
        time.sleep(WATCHDOG_POLL_SEC)


def start_motor_watchdog():
    Thread(target=motor_watchdog, daemon=True).start()


def stop_motor_watchdog():
    global _motor_watchdog_running
    _motor_watchdog_running = False


# Ensure safe shutdown
atexit.register(stop_all_motors)
atexit.register(stop_motor_watchdog)

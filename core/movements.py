import atexit
import contextlib
import random
import threading
import time
from threading import Lock, Thread

import numpy as np

from .config import BILLY_PINS, MOCKFISH, is_classic_billy
from .logger import logger


# === Adafruit MotorKit Support ===
motor_kit = None
use_motor_kit = False

try:
    import board
    from adafruit_motorkit import MotorKit
    motor_kit = MotorKit(i2c=board.I2C())
    use_motor_kit = BILLY_PINS == "adafruit_motor_hat"
    if use_motor_kit:
        logger.info("MotorKit initialized for adafruit_motor_hat", "🔧")
except (ImportError, Exception) as e:
    if BILLY_PINS == "adafruit_motor_hat":
        logger.warning(f"MotorKit not available: {e}", "⚠️")

# === lgpio GPIO Support ===
try:
    import lgpio

    lgpio_available = True
except ImportError:
    lgpio_available = False

if MOCKFISH or (not lgpio_available and not use_motor_kit):
    # Mock lgpio for development or when not available
    class MockLgpio:
        error = Exception

        @staticmethod
        def gpiochip_open(chip):
            return "mock_handle"

        @staticmethod
        def gpio_claim_output(h, pin):
            pass

        @staticmethod
        def gpio_write(h, pin, value):
            pass

        @staticmethod
        def tx_pwm(h, pin, freq, duty):
            pass

        @staticmethod
        def gpio_free(h, pin):
            pass

        @staticmethod
        def gpiochip_close(h):
            pass

    lgpio = MockLgpio
    if MOCKFISH:
        logger.info("Mockfish: GPIO mocked for development", "🐟")
    elif not use_motor_kit:
        logger.info("lgpio not available: GPIO mocked", "🐟")


# === Configuration ===
USE_THIRD_MOTOR = is_classic_billy()
logger.info(f"Using third motor: {USE_THIRD_MOTOR} | Pin profile: {BILLY_PINS}", "⚙️")

# === GPIO/Motor Setup ===
if use_motor_kit:
    h = None
    FREQ = 10000  # Not directly used for MotorKit
    _gpio_active = True  # MotorKit is always active if initialized
else:
    h = lgpio.gpiochip_open(0)
    FREQ = 10000  # PWM frequency
    _gpio_active = True  # Flag to track if GPIO handle is still valid

# -------------------------------------------------------------------
# Pin/Motor mapping by profile
# -------------------------------------------------------------------
# We normalize to three "drive" pins (MOUTH, HEAD, TAIL) and up to three
# "mates" that must be held LOW for legacy wiring (GND_1..GND_3).
MOUTH = GND_1 = HEAD = TAIL = GND_2 = GND_3 = None
MOUTH_MOTOR = HEAD_MOTOR = TAIL_MOTOR = None

if use_motor_kit:
    # MotorKit mapping: motor1=mouth, motor2=tail, motor3=head (optional)
    MOUTH_MOTOR = motor_kit.motor1
    if USE_THIRD_MOTOR:
        TAIL_MOTOR = motor_kit.motor2
        HEAD_MOTOR = motor_kit.motor3
    else:
        TAIL_MOTOR = motor_kit.motor2
        HEAD_MOTOR = None
    # For compatibility, still track pin numbers (not used for MotorKit)
    MOUTH = 1
    TAIL = 2
    HEAD = 3 if USE_THIRD_MOTOR else 2
elif BILLY_PINS == "legacy":
    # Original wiring (backwards compatible)
    # Controller 1: IN1=HEAD, IN2=TAIL (2-motor legacy) | IN3=MOUTH, IN4=GND_1
    MOUTH = 12
    HEAD = 13
    TAIL = 6
    GND_1 = 5
    if USE_THIRD_MOTOR:
        # Classic Billy (3 motors): dedicated tail bridge on second driver
        TAIL = 19  # second driver IN1 (PWM)
        GND_2 = 6  # head mate (keep LOW)
        GND_3 = 26  # tail mate (keep LOW)
else:
    # NEW quiet wiring (mates are tied to GND in hardware)
    HEAD = 22  # pin 15
    MOUTH = 17  # pin 11
    TAIL = 27  # pin 13

# Collect all pins we actually use
motor_pins = [p for p in (MOUTH, HEAD, TAIL, GND_1, GND_2, GND_3) if p is not None]

# Claim/initialize GPIO pins (skip for MotorKit)
if not use_motor_kit:
    for pin in motor_pins:
        try:
            lgpio.gpio_claim_output(h, pin)
            lgpio.gpio_write(h, pin, 0)
        except lgpio.error as e:
            if "GPIO busy" in str(e) or "busy" in str(e).lower():
                # Pin is already claimed (likely from a previous crashed instance)
                # Try to free it first, then claim it again
                logger.warning(
                    f"GPIO pin {pin} is busy, attempting to free and reclaim...", "⚠️"
                )
                try:
                    # Try to free the pin (may fail if not claimed by this handle, but worth trying)
                    with contextlib.suppress(lgpio.error, Exception):
                        lgpio.gpio_free(h, pin)
                    # Wait a bit for the kernel to clean up
                    time.sleep(0.2)
                    # Now try to claim it again
                    lgpio.gpio_claim_output(h, pin)
                    lgpio.gpio_write(h, pin, 0)
                    logger.info(f"Successfully reclaimed GPIO pin {pin}", "✅")
                except Exception as free_error:
                    logger.error(
                        f"Failed to free/reclaim GPIO pin {pin}: {free_error}", "❌"
                    )
                    raise
            else:
                # Some other GPIO error - re-raise it
                raise

# === State ===
_head_tail_lock = Lock()
_motor_watchdog_running = False
_last_flap = 0
_mouth_open_until = 0
_last_rms = 0
head_out = False

# === Throttle/PWM tracking (so watchdog can see motor activity) ===
_throttle = {pin: {"throttle": 0, "since": None} for pin in motor_pins}
_pwm = {pin: {"duty": 0, "since": None} for pin in motor_pins}

# Direction flip configuration for MotorKit
FLIP_MOUTH_DIRECTION = True
FLIP_HEAD_DIRECTION = False
FLIP_TAIL_DIRECTION = True


def set_throttle(motor, throttle_percent):
q

def clear_throttle(motor):
    """Stop MotorKit motor and clear active since timestamp."""
    if not use_motor_kit or motor is None:
        return
    motor.throttle = 0
    motor_id = MOUTH if motor == MOUTH_MOTOR else HEAD if motor == HEAD_MOTOR else TAIL if motor == TAIL_MOTOR else None
    if motor_id is not None:
        _throttle[motor_id]["throttle"] = 0
        _throttle[motor_id]["since"] = None


def set_pwm(pin: int, duty: int):
    """Start/adjust PWM on GPIO pin and remember when it went active."""
    global _gpio_active
    if use_motor_kit or not _gpio_active:
        return
    try:
        lgpio.tx_pwm(h, pin, FREQ, int(duty))
    except (lgpio.error, Exception):
        _gpio_active = False
        return
    if duty > 0:
        _pwm[pin]["duty"] = int(duty)
        if _pwm[pin]["since"] is None:
            _pwm[pin]["since"] = time.time()
    else:
        _pwm[pin]["duty"] = 0
        _pwm[pin]["since"] = None


def clear_pwm(pin: int):
    """Stop PWM on GPIO pin and clear active since timestamp."""
    global _gpio_active
    if use_motor_kit or not _gpio_active:
        return
    try:
        lgpio.tx_pwm(h, pin, FREQ, 0)
    except (lgpio.error, Exception):
        _gpio_active = False
        return
    _pwm[pin]["duty"] = 0
    _pwm[pin]["since"] = None


# === Motor Helpers ===
def brake_motor(pin1, pin2=None):
    """Actively stop the channel: zero throttle/PWM and drive LOW."""
    global _gpio_active
    if use_motor_kit:
        motor = MOUTH_MOTOR if pin1 == MOUTH else HEAD_MOTOR if pin1 == HEAD else TAIL_MOTOR if pin1 == TAIL else None
        if motor is not None:
            clear_throttle(motor)
    else:
        if not _gpio_active:
            return
        clear_pwm(pin1)
        if pin2 is not None:
            clear_pwm(pin2)
            try:
                lgpio.gpio_write(h, pin2, 0)
            except (lgpio.error, Exception):
                _gpio_active = False
                return
        try:
            lgpio.gpio_write(h, pin1, 0)
        except (lgpio.error, Exception):
            _gpio_active = False
            return


def run_motor_async(motor_pin, low_pin=None, speed_percent=100, duration=0.3, brake=True):
    """Run motor asynchronously with optional brake and timeout."""
    global _gpio_active
    if use_motor_kit:
        motor = MOUTH_MOTOR if motor_pin == MOUTH else HEAD_MOTOR if motor_pin == HEAD else TAIL_MOTOR if motor_pin == TAIL else None
        if motor is not None:
            set_throttle(motor, float(speed_percent))
            callback = (lambda: brake_motor(motor_pin, low_pin)) if brake else (lambda: clear_throttle(motor))
            threading.Timer(duration, callback).start()
    else:
        if not _gpio_active:
            return
        if low_pin is not None:
            try:
                lgpio.gpio_write(h, low_pin, 0)
            except (lgpio.error, Exception):
                _gpio_active = False
                return
        set_pwm(motor_pin, int(speed_percent))
        callback = (lambda: brake_motor(motor_pin, low_pin)) if brake else (lambda: clear_pwm(motor_pin))
        threading.Timer(duration, callback).start()


# === Movement Functions (keep signatures/behavior) ===
def move_mouth(speed_percent, duration, brake=False):
    run_motor_async(MOUTH, GND_1, speed_percent, duration, brake)


def stop_mouth():
    brake_motor(MOUTH, GND_1)


def move_head(state="on"):
    global head_out

    def _move_head_on():
        global _gpio_active
        if use_motor_kit:
            if HEAD_MOTOR is not None:
                set_throttle(HEAD_MOTOR, 80)
                time.sleep(0.5)
                set_throttle(HEAD_MOTOR, 100)
        else:
            if not _gpio_active:
                return
            if TAIL is not None:
                try:
                    lgpio.gpio_write(h, TAIL, 0)
                except (lgpio.error, Exception):
                    _gpio_active = False
                    return
            set_pwm(HEAD, 80)
            time.sleep(0.5)
            set_pwm(HEAD, 100)

    if state == "on":
        if not head_out:
            threading.Thread(target=_move_head_on, daemon=True).start()
            head_out = True
    else:
        brake_motor(HEAD, TAIL)
        head_out = False


def move_tail(duration=0.2):
    """
    Tail drive matrix:
      - adafruit_motor_hat + classic(3): TAIL_MOTOR (motor2)
      - adafruit_motor_hat + modern(2):  TAIL_MOTOR (motor2)
      - legacy + classic(3): TAIL has dedicated bridge => mate = GND_3
      - legacy + modern(2):  shared with HEAD => mate = HEAD
      - new    + classic(3): dedicated channel with mate tied to GND => mate = None
      - new    + modern(2):  shared bridge with HEAD => mate = HEAD
    """
    if use_motor_kit:
        if TAIL_MOTOR is not None:
            run_motor_async(TAIL, None, speed_percent=80, duration=duration)
    elif BILLY_PINS == "legacy":
        if USE_THIRD_MOTOR and TAIL is not None and GND_3 is not None:
            run_motor_async(TAIL, GND_3, speed_percent=80, duration=duration)
        else:
            run_motor_async(TAIL, HEAD, speed_percent=80, duration=duration)
    else:
        if USE_THIRD_MOTOR:
            run_motor_async(TAIL, None, speed_percent=80, duration=duration)
        else:
            run_motor_async(TAIL, HEAD, speed_percent=80, duration=duration)


def move_tail_async(duration=0.3):
    threading.Thread(target=move_tail, args=(duration,), daemon=True).start()


def _articulation_multiplier():
    """Return direct articulation multiplier (1 = normal, higher = slower)."""
    try:
        # Try to get mouth articulation from current persona
        from .persona_manager import persona_manager

        current_persona_data = persona_manager.get_current_persona_data()

        if current_persona_data and current_persona_data.get('meta', {}).get(
            'mouth_articulation'
        ):
            persona_articulation = current_persona_data['meta']['mouth_articulation']
            return max(0, min(10, float(persona_articulation)))
        # Fall back to global setting
        return 5
    except Exception as e:
        # Fall back to global setting on error
        return 5


# === Mouth Sync ===
def flap_from_pcm_chunk(
    audio, threshold=1500, min_flap_gap=0.15, chunk_ms=40, sample_rate=24000
):
    global _last_flap, _mouth_open_until, _last_rms
    now = time.time()

    if audio.size == 0:
        return

    rms = np.sqrt(np.mean(audio.astype(np.float32) ** 2))
    peak = np.max(np.abs(audio))

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
    dyn_range = peak / (rms + 1e-5)

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
        for _ in range(random.randint(1, 3)):
            move_tail()
            time.sleep(random.uniform(0.25, 0.9))
        if random.random() < 0.9:
            move_head("on")
            threading.Timer(5.0, lambda: move_head("off")).start()
    except Exception:
        print("⚠️ Interlude error")


def interlude():
    """Run head/tail interlude in a background thread if not already running."""
    if _head_tail_lock.locked():
        return
    Thread(target=lambda: _interlude_routine(), daemon=True).start()


# === Motor Watchdog (per-pin continuous activity) ===
WATCHDOG_TIMEOUT_SEC = 30  # max continuous ON time per pin
WATCHDOG_POLL_SEC = 1.0  # poll cadence


def _mate_for(pin: int):
    """
    Return the logical 'mate' input that should be LOW when 'pin' drives.
    This lets the watchdog brake a channel safely.
    """
    if pin == MOUTH:
        return GND_1
    if pin == HEAD:
        if BILLY_PINS == "legacy":
            # legacy modern shares bridge with tail
            return TAIL
        # new layout: 3-motor => mate hard GND (None); 2-motor => mate is TAIL
        return None if USE_THIRD_MOTOR else TAIL
    if pin == TAIL:
        if BILLY_PINS == "legacy":
            return GND_3 if USE_THIRD_MOTOR else HEAD
        return None if USE_THIRD_MOTOR else HEAD
    return None


def _stop_channel(pin: int):
    """Brake one channel safely (pin + its mate)."""
    global _gpio_active
    if not _gpio_active:
        return  # GPIO handle already closed, skip
    mate = _mate_for(pin)
    clear_pwm(pin)
    try:
        lgpio.gpio_write(h, pin, 0)
    except (lgpio.error, Exception):
        _gpio_active = False
        return
    if mate is not None:
        clear_pwm(mate)
        try:
            lgpio.gpio_write(h, mate, 0)
        except (lgpio.error, Exception):
            _gpio_active = False
            return


def _pin_is_active(pin: int) -> bool:
    """Active if line is HIGH or PWM/throttle duty > 0."""
    if use_motor_kit:
        # For MotorKit, check throttle state
        return abs(_throttle.get(pin, {}).get("throttle", 0)) > 0
    else:
        # For GPIO mode
        if not _gpio_active:
            # If GPIO is inactive, only check PWM state
            return _pwm.get(pin, {}).get("duty", 0) > 0
        try:
            if lgpio.gpio_read(h, pin) == 1:
                return True
        except (lgpio.error, Exception):
            # Handle might be closed, fall back to PWM state
            pass
        return _pwm.get(pin, {}).get("duty", 0) > 0


def stop_all_motors():
    global _gpio_active
    logger.info("Stopping all motors", "🛑")
    if use_motor_kit:
        for motor in [MOUTH_MOTOR, HEAD_MOTOR, TAIL_MOTOR]:
            if motor is not None:
                clear_throttle(motor)
    elif _gpio_active:
        for pin in motor_pins:
            clear_pwm(pin)
            try:
                lgpio.gpio_write(h, pin, 0)
            except (lgpio.error, Exception):
                _gpio_active = False
                return


def cleanup_gpio():
    """Close GPIO chip handle to prevent memory corruption on shutdown."""
    global _gpio_active
    try:
        if use_motor_kit:
            stop_all_motors()
            logger.info("MotorKit cleanup complete", "✅")
        else:
            _gpio_active = False
            stop_all_motors()
            time.sleep(0.1)
            for pin in motor_pins:
                with contextlib.suppress(lgpio.error, Exception):
                    lgpio.gpio_free(h, pin)
            with contextlib.suppress(lgpio.error, Exception):
                lgpio.gpiochip_close(h)
            logger.info("GPIO cleanup complete", "✅")
    except Exception:
        logger.warning("Cleanup error", "⚠️")


def is_motor_active():
    return any(_pin_is_active(pin) for pin in motor_pins)


def motor_watchdog():
    """Stop any single pin that stays active longer than WATCHDOG_TIMEOUT_SEC."""
    global _motor_watchdog_running
    _motor_watchdog_running = True
    since_on = {pin: None for pin in motor_pins}

    while _motor_watchdog_running:
        now = time.time()
        for pin in motor_pins:
            if _pin_is_active(pin):
                if since_on[pin] is None:
                    since_on[pin] = now
                elif (now - since_on[pin]) >= WATCHDOG_TIMEOUT_SEC:
                    logger.warning(f"Watchdog: pin {pin} active > {WATCHDOG_TIMEOUT_SEC}s → braking channel", "⏱️")
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
atexit.register(cleanup_gpio)
atexit.register(stop_all_motors)
atexit.register(stop_motor_watchdog)

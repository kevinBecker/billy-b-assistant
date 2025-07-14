import signal
import sys
import threading
import traceback

import core.button
from core.audio import playback_queue
from core.movements import start_motor_watchdog, stop_all_motors
from core.mqtt import start_mqtt, stop_mqtt


def signal_handler(sig, frame):
    print("\n👋 Exiting cleanly (signal received).")
    playback_queue.put(None)
    stop_all_motors()
    stop_mqtt()
    sys.exit(0)


def main():
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    threading.Thread(target=start_mqtt, daemon=True).start()
    start_motor_watchdog()
    core.button.start_loop()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("❌ Unhandled exception occurred:", e)
        traceback.print_exc()
        stop_all_motors()
        stop_mqtt()
        sys.exit(1)

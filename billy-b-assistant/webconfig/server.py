import configparser
import json
import os
import queue
import re
import subprocess
import sys

import numpy as np
import sounddevice as sd
from dotenv import find_dotenv, set_key
from flask import Flask, Response, jsonify, render_template, request


# Add parent directory to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from core import config as core_config


app = Flask(__name__)

# Load and cache environment variables from .env
ENV_PATH = find_dotenv()
CONFIG_KEYS = [
    "OPENAI_API_KEY",
    "VOICE",
    "MIC_TIMEOUT_SECONDS",
    "SILENCE_THRESHOLD",
    "MQTT_HOST",
    "MQTT_PORT",
    "MQTT_USERNAME",
    "MQTT_PASSWORD",
    "HA_HOST",
    "HA_TOKEN",
    "HA_LANG",
    "MIC_PREFERENCE",
    "SPEAKER_PREFERENCE",
]


def load_env():
    return {
        "OPENAI_API_KEY": core_config.OPENAI_API_KEY,
        "VOICE": core_config.VOICE,
        "VOICE_OPTIONS": [
            "ash",
            "ballad",
            "coral",
            "sage",
            "verse",
            "alloy",
            "echo",
            "fable",
            "nova",
        ],
        "MIC_TIMEOUT_SECONDS": str(core_config.MIC_TIMEOUT_SECONDS),
        "SILENCE_THRESHOLD": str(core_config.SILENCE_THRESHOLD),
        "MQTT_HOST": core_config.MQTT_HOST,
        "MQTT_PORT": str(core_config.MQTT_PORT),
        "MQTT_USERNAME": core_config.MQTT_USERNAME,
        "MQTT_PASSWORD": core_config.MQTT_PASSWORD,
        "HA_HOST": getattr(core_config, "HA_HOST", ""),
        "HA_TOKEN": getattr(core_config, "HA_TOKEN", ""),
        "HA_LANG": getattr(core_config, "HA_LANG", ""),
        "MIC_PREFERENCE": core_config.MIC_PREFERENCE,
        "SPEAKER_PREFERENCE": core_config.SPEAKER_PREFERENCE,
    }


@app.route("/")
def index():
    return render_template("index.html", config=load_env())


@app.route("/save", methods=["POST"])
def save():
    data = request.json
    for key, value in data.items():
        if key in CONFIG_KEYS:
            set_key(ENV_PATH, key, value)
    return jsonify({"status": "ok"})


@app.route("/config")
def get_config():
    return jsonify(load_env())


@app.route("/logs")
def logs():
    try:
        output = subprocess.check_output([
            "journalctl",
            "-u",
            "billy.service",
            "-n",
            "100",
            "--no-pager",
            "--output=short",
        ])
        return jsonify({"logs": output.decode("utf-8")})
    except subprocess.CalledProcessError as e:
        return jsonify({"logs": "Failed to retrieve logs", "error": str(e)}), 500


@app.route("/service/<action>")
def control_service(action):
    if action not in ["start", "stop", "restart"]:
        return jsonify({"error": "Invalid action"}), 400
    try:
        subprocess.check_call(["sudo", "systemctl", action, "billy.service"])
        return jsonify({"status": "success", "action": action})
    except subprocess.CalledProcessError:
        return jsonify({"error": "Failed to run systemctl"}), 500


@app.route("/service/status")
def service_status():
    try:
        output = subprocess.check_output(
            ["systemctl", "is-active", "billy.service"], stderr=subprocess.STDOUT
        )
        return jsonify({"status": output.decode("utf-8").strip()})
    except subprocess.CalledProcessError as e:
        return jsonify({"status": e.output.decode("utf-8").strip()})


PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PERSONA_PATH = os.path.join(PROJECT_ROOT, "persona.ini")


@app.route("/persona", methods=["GET"])
def get_persona():
    config = configparser.ConfigParser()
    config.read(PERSONA_PATH)

    return jsonify({
        "PERSONALITY": dict(config["PERSONALITY"]) if "PERSONALITY" in config else {},
        "BACKSTORY": dict(config["BACKSTORY"]) if "BACKSTORY" in config else {},
        "META": config["META"].get("instructions", "") if "META" in config else "",
    })


@app.route("/persona", methods=["POST"])
def save_persona():
    data = request.json
    config = configparser.ConfigParser()

    config["PERSONALITY"] = {k: str(v) for k, v in data.get("PERSONALITY", {}).items()}
    config["BACKSTORY"] = data.get("BACKSTORY", {})
    config["META"] = {"instructions": data.get("META", "")}

    with open(PERSONA_PATH, "w") as f:
        config.write(f)
    return jsonify({"status": "ok"})


rms_queue = queue.Queue()
mic_check_running = False


def audio_callback(indata, frames, time_info, status):
    if not mic_check_running:
        raise sd.CallbackStop()
    rms = float(np.sqrt(np.mean(np.square(indata))))
    rms_queue.put(rms)


@app.route("/mic-check")
def mic_check():
    def rms_stream_generator():
        global mic_check_running
        mic_check_running = True

        try:
            with sd.InputStream(callback=audio_callback):
                while mic_check_running:
                    try:
                        rms = rms_queue.get(timeout=1.0)
                        payload = {
                            "rms": round(rms, 4),
                            "threshold": round(float(core_config.SILENCE_THRESHOLD), 4),
                        }
                        yield f"data: {json.dumps(payload)}\n\n"
                    except queue.Empty:
                        continue
        except Exception as e:
            print("RMS stream error:", e)
            yield f"data: {json.dumps({'error': str(e)})}\n\n"

    return Response(rms_stream_generator(), mimetype="text/event-stream")


@app.route("/mic-check/stop")
def mic_check_stop():
    global mic_check_running
    mic_check_running = False
    return jsonify({"status": "stopped"})


@app.route("/mic-gain", methods=["GET", "POST"])
def mic_gain():
    if request.method == "GET":
        try:
            output = subprocess.check_output(["amixer", "cget", "numid=3"], text=True)
            match = re.search(r": values=(\d+)", output)
            gain = int(match.group(1)) if match else None
            return jsonify({"gain": gain})
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    if request.method == "POST":
        try:
            data = request.get_json()
            value = int(data.get("value", 8))  # default to midrange
            if 0 <= value <= 16:
                subprocess.check_call(["amixer", "cset", "numid=3", str(value)])
                return "OK"
            return jsonify({"error": "Mic gain must be between 0 and 16"}), 400
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    return jsonify({"error": "Unsupported method"}), 405


@app.route("/device-info")
def device_info():
    try:
        devices = sd.query_devices()

        mic_name = "Unknown"
        speaker_name = "Unknown"

        for dev in devices:
            # Set mic name
            if (
                mic_name == "Unknown"
                and dev["max_input_channels"] > 0
                and (
                    not core_config.MIC_PREFERENCE
                    or core_config.MIC_PREFERENCE.lower() in dev["name"].lower()
                )
            ):
                mic_name = dev["name"]

            # Set speaker name
            if (
                speaker_name == "Unknown"
                and dev["max_output_channels"] > 0
                and (
                    not core_config.SPEAKER_PREFERENCE
                    or core_config.SPEAKER_PREFERENCE.lower() in dev["name"].lower()
                )
            ):
                speaker_name = dev["name"]

        return jsonify({"mic": mic_name, "speaker": speaker_name})

    except Exception as e:
        return jsonify({"mic": "Unknown", "speaker": "Unknown", "error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)

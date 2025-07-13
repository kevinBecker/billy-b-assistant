from flask import Flask, render_template, request, jsonify, Response
import subprocess
import os
import configparser
import threading
import time
import json
import numpy as np
import sounddevice as sd
import queue
from dotenv import dotenv_values, set_key, find_dotenv

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
    "HA_URL",
    "HA_TOKEN",
    "HA_LANG"
]

def load_env():
    config = dotenv_values(ENV_PATH)
    return {key: config.get(key, "") for key in CONFIG_KEYS}

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
            "journalctl", "-u", "billy.service", "-n", "100", "--no-pager", "--output=short"
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
            ["systemctl", "is-active", "billy.service"],
            stderr=subprocess.STDOUT
        )
        return jsonify({"status": output.decode("utf-8").strip()})
    except subprocess.CalledProcessError as e:
        # Even if the service is inactive, this gives us the actual status
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
        "META": config["META"].get("instructions", "") if "META" in config else ""
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
                            "threshold": round(float(load_env().get("SILENCE_THRESHOLD", 0.01)), 4)
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

@app.route("/mic-gain")
def set_mic_gain():
    value = request.args.get("value", "80")
    try:
        subprocess.check_call(["amixer", "set", "Capture", f"{value}%"])
        return "OK"
    except Exception as e:
        return str(e), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
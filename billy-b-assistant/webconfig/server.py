from flask import Flask, render_template, request, jsonify
import subprocess
import os
import configparser
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

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=True)
import subprocess
import time

from flask import Flask, render_template_string, request


app = Flask(__name__)

FORM = """
<!DOCTYPE html>
<html>
<head><title>Connect Billy</title></head>
<body>
<h2>Connect Billy to Wi-Fi</h2>
<form method="POST">
  <label>SSID: <input name="ssid" /></label><br/>
  <label>Password: <input name="password" type="password" /></label><br/>
  <button type="submit">Connect</button>
</form>
</body>
</html>
"""


@app.route("/", methods=["GET", "POST"])
def onboarding():
    if request.method == "POST":
        ssid = request.form["ssid"]
        password = request.form["password"]
        save_wifi_credentials(ssid, password)
        return "Billy is connecting to Wi-Fi... You can close this tab."
    return render_template_string(FORM)


def save_wifi_credentials(ssid, password):
    try:
        subprocess.run(["sudo", "systemctl", "start", "NetworkManager"], check=True)

        subprocess.run(["nmcli", "radio", "wifi", "on"], check=False)
        subprocess.run(["nmcli", "dev", "wifi", "rescan"], check=False)
        time.sleep(2)
        subprocess.run(["nmcli", "dev", "wifi", "list"])
        time.sleep(2)
        subprocess.run(
            [
                "nmcli",
                "dev",
                "wifi",
                "connect",
                ssid,
                "password",
                password,
                "ifname",
                "wlan0",
            ],
            check=True,
        )

        subprocess.run(
            ["sudo", "systemctl", "stop", "billy-onboarding.service"], check=False
        )

        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to connect to {ssid}: {e}")
        return False


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)

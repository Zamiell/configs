import subprocess

result = subprocess.run(["wmctrl", "-x", "-a", "google-chrome.Google-chrome"])
if result.returncode != 0:
    subprocess.Popen(["google-chrome"])

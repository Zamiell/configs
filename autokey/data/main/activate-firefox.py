import subprocess

result = subprocess.run(["wmctrl", "-x", "-a", "Navigator.firefox"])
if result.returncode != 0:
    subprocess.Popen(["firefox"])

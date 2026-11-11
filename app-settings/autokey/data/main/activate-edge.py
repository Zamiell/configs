import subprocess

result = subprocess.run(["wmctrl", "-x", "-a", "microsoft-edge.Microsoft-edge"])
if result.returncode != 0:
    subprocess.Popen(["microsoft-edge"])

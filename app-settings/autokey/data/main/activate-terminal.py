import subprocess

result = subprocess.run(["wmctrl", "-x", "-a", "konsole.Konsole"])
if result.returncode != 0:
    subprocess.Popen(["konsole"])

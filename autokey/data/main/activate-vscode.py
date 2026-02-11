import subprocess

result = subprocess.run(["wmctrl", "-x", "-a", "code.Code"])
if result.returncode != 0:
    subprocess.Popen(["code"])

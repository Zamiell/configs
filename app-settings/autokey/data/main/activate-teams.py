import subprocess

result = subprocess.run(["wmctrl", "-a", "Microsoft Teams (PWA)"])
if result.returncode != 0:
    subprocess.Popen([
        "microsoft-edge",
        "--profile-directory=Default",
        "--app-id=ompifgpmddkgmclendfeacglnodjjndh", # cspell: disable-line
        "--app-url=https://teams.cloud.microsoft/?clientType=pwa",
    ])

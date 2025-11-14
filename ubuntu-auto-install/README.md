# Ubuntu Installation Automation

1. Use [Rufus](https://rufus.ie/en/) to create a USB drive from an Ubuntu Server installation ISO.

2. Copy the the following files to the USB drive:
   - autoinstall.yaml
   - boot/grub/grub.cfg
   - post-install

3. Open the copied "autoinstall.yaml" file and change:
   - The BitWarden API client secret:
     - `- echo "hunter2" > /target/post-install/bitwarden_api_client_secret`
   - The BitWarden master password:
     - `echo "hunter2" > /target/post-install/bitwarden_master_password`
   - The disk encryption password:
     - `password: "hunter2"`

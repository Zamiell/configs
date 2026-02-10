# Ubuntu Installation Automation

1. Use [Rufus](https://rufus.ie/en/) to create a USB drive from an Ubuntu Server installation ISO.

2. Copy the the following files to the USB drive:
   - autoinstall.yaml
   - boot/grub/grub.cfg
   - post-install

3. Open the copied "autoinstall.yaml" file and change the disk encryption password:
   - `password: "hunter2"`

4. Copy the "id_ed25519" private key file to the "post-install/.ssh" directory.

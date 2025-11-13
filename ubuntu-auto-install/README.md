# Ubuntu Installation Automation

1. Use [Rufus](https://rufus.ie/en/) to create a USB drive from an Ubuntu Server installation ISO.

2. Copy the the following files to the USB drive:
   - autoinstall.yaml
   - boot/grub/grub.cfg
   - post-install

3. Open the copied "autoinstall.yaml" file and change the two instances of "hunter2". (One is for the disk encryption password and one is for the BitWarden master password.)

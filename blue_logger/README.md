# Capturing debug logs over bluetooth

When developing embedded applications (e.g. on nRF52), it comes in very handy
to capture logs over bluetooth; this saves some soldering. Doing so requires
some preparation:

- place `rfcomm.service` in `/etc/systemd/system` and enable it
- place `bluetooth.service` in `/lib/systemd/system` (you may backup the
  existing file)
- place `logger` in `/home/pi/bin`
- put `PRETTY_HOSTNAME=rpi1` (or however you want to call it) into
  `/etc/machine-info`
- reboot

Now, whenever a serial connection comes in over bluetooth, the logger will be
started and place a file in `/home/pi/log` to capture the logs. You may test
this by connecting to the pi from your computer and using the new serial device
(/dev/cu.* on macos) to send characters; you may also use `screen
/dev/cu.<name>` to open a terminal and start typing (use `C-a k` to exit).

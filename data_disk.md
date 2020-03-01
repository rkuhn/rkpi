# Mount USB-disk at `/data`

If you want to attach a USB mass storage device such that

- it is hot-pluggable
- always mounted at the same path
- and automatically mounted/unmounted as you plug/unplug it

then that’s surprisingly oblique in the systemd world.

## The `.mount` unit

First, we’ll have to explain to systemd that we want to mount a device at a given path. This is best
done by creating a unit for this purpose, like `/etc/systemd/system/data.mount`:

```
[Unit]
Requires=systemd-fsck@dev-data.service
After=systemd-fsck@dev-data.service

[Mount]
Where=/data
What=/dev/data
Type=ext4
```

Unfortunately, mount units cannot be templates: the extremely unhelpful error message “Invalid
argument” will tell you that the name of the unit does not exactly coincide with the “Where”
parameter (in escaped form).

## The udev rules

We need to trigger the start of the above unit whenever the USB device is attached. Due to
unfortunate quirks in the udev system, this is less straight-forward than it could be, see
`/etc/udev/rules/70-data.rules` (it is important that this runs after the `60-*` scripts):

```
ACTION=="remove", GOTO="rk_data_end"

SUBSYSTEM=="block", ENV{ID_FS_UUID}=="<UUID>", SYMLINK+="data"
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_UUID}=="<UUID>", RUN+="/bin/systemctl start --no-ask-password --no-block data.mount"

LABEL="rk_data_end"
```

The first line expresses that we want the symlink for all actions except “remove”; in particular,
adding the symlink only in “add” will lead to its removal soon thereafter when the “bind” kernel
event is processed (which takes the form of a “change” event). You get the filesystem UUID — which
is the recommended way of identifying a filesystem — using the `lsblk` command. Finally, it is not
possible to mount filesystems directly from udev rules, so we enqueue the start command for the
aforementioned `data.mount` systemd unit. Here it is important to disable asking for a password
(which will just lead to the command exiting with status 1 and no further explanation) and to not
wait for the completion of the mount (since fsck may or may not take many seconds, during which we
don’t want to keep udev from doing other work).

## Quirks

If you experience trouble with the disk in the form of controller resets (those really ruin the day
when watching movies, or when waiting a minute for the initial recognition of the partition table),
you may need to opt out of UAS mode. In my case, this was the situation in `/var/log/syslog`:

```
Mar  1 07:32:09 rpi2 kernel: [79859.819875] usb 2-1: new SuperSpeed Gen 1 USB device number 7 using xhci_hcd
Mar  1 07:32:09 rpi2 kernel: [79859.851125] usb 2-1: New USB device found, idVendor=152d, idProduct=0578, bcdDevice= 3.01
Mar  1 07:32:09 rpi2 kernel: [79859.851141] usb 2-1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
Mar  1 07:32:09 rpi2 kernel: [79859.851154] usb 2-1: Product: USB 3.0 Device
Mar  1 07:32:09 rpi2 kernel: [79859.851166] usb 2-1: Manufacturer: USB 3.0 Device
Mar  1 07:32:09 rpi2 kernel: [79859.851178] usb 2-1: SerialNumber: 000000004BA8
Mar  1 07:32:09 rpi2 kernel: [79859.864711] scsi host0: uas
Mar  1 07:32:09 rpi2 kernel: [79859.866722] scsi 0:0:0:0: Direct-Access     Samsung  SSD 860 QVO 2TB  0301 PQ: 0 ANSI: 6
Mar  1 07:32:09 rpi2 kernel: [79859.868151] sd 0:0:0:0: Attached scsi generic sg0 type 0
Mar  1 07:32:09 rpi2 kernel: [79859.872297] sd 0:0:0:0: [sda] 3907029168 512-byte logical blocks: (2.00 TB/1.82 TiB)
Mar  1 07:32:09 rpi2 kernel: [79859.872313] sd 0:0:0:0: [sda] 4096-byte physical blocks
Mar  1 07:32:09 rpi2 kernel: [79859.872527] sd 0:0:0:0: [sda] Write Protect is off
Mar  1 07:32:09 rpi2 kernel: [79859.872546] sd 0:0:0:0: [sda] Mode Sense: 53 00 00 08
Mar  1 07:32:09 rpi2 kernel: [79859.872940] sd 0:0:0:0: [sda] Disabling FUA
Mar  1 07:32:09 rpi2 kernel: [79859.872956] sd 0:0:0:0: [sda] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
Mar  1 07:32:09 rpi2 kernel: [79859.873672] sd 0:0:0:0: [sda] Optimal transfer size 33553920 bytes not a multiple of physical block size (4096 bytes)
Mar  1 07:32:40 rpi2 kernel: [79890.560332] sd 0:0:0:0: [sda] tag#27 uas_eh_abort_handler 0 uas-tag 5 inflight: CMD IN 
Mar  1 07:32:40 rpi2 kernel: [79890.560351] sd 0:0:0:0: [sda] tag#27 CDB: opcode=0x28 28 00 e8 e0 85 28 00 00 a8 00
Mar  1 07:32:40 rpi2 kernel: [79890.560595] sd 0:0:0:0: [sda] tag#0 uas_eh_abort_handler 0 uas-tag 6 inflight: CMD IN 
Mar  1 07:32:40 rpi2 kernel: [79890.560609] sd 0:0:0:0: [sda] tag#0 CDB: opcode=0x28 28 00 e8 e0 85 d8 00 00 28 00
Mar  1 07:32:40 rpi2 kernel: [79890.600342] scsi host0: uas_eh_device_reset_handler start
Mar  1 07:32:40 rpi2 kernel: [79890.751186] usb 2-1: reset SuperSpeed Gen 1 USB device number 7 using xhci_hcd
Mar  1 07:32:40 rpi2 kernel: [79890.787720] scsi host0: uas_eh_device_reset_handler success
Mar  1 07:33:11 rpi2 kernel: [79921.281143] sd 0:0:0:0: [sda] tag#16 uas_eh_abort_handler 0 uas-tag 3 inflight: CMD IN 
Mar  1 07:33:11 rpi2 kernel: [79921.281162] sd 0:0:0:0: [sda] tag#16 CDB: opcode=0x28 28 00 e8 e0 87 b8 00 00 48 00
Mar  1 07:33:11 rpi2 kernel: [79921.321119] scsi host0: uas_eh_device_reset_handler start
Mar  1 07:33:11 rpi2 kernel: [79921.471986] usb 2-1: reset SuperSpeed Gen 1 USB device number 7 using xhci_hcd
Mar  1 07:33:11 rpi2 kernel: [79921.508441] scsi host0: uas_eh_device_reset_handler success
```

Note how it takes 62sec until the second reset is done, at which point the device and its partitions became visible to udev etc.

It turns out that the JMS567 chipset does not actually fully support scatter-gather IO — who knew?
The way to get a working system (and still >300MB/s read transfer rate while streaming) is to add
the following (adapted for your idVendor and idProduct) to `/boot/cmdline.txt`:

    usb-storage.quirks=152d:0578:u [and then the rest]

With this, the device startup looks like the following:

```
Mar  1 17:41:30 rpi2 kernel: [    6.728574] usb 2-1: new SuperSpeed Gen 1 USB device number 2 using xhci_hcd
Mar  1 17:41:30 rpi2 kernel: [    6.759812] usb 2-1: New USB device found, idVendor=152d, idProduct=0578, bcdDevice= 3.01
Mar  1 17:41:30 rpi2 kernel: [    6.759828] usb 2-1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
Mar  1 17:41:30 rpi2 kernel: [    6.759841] usb 2-1: Product: USB 3.0 Device
Mar  1 17:41:30 rpi2 kernel: [    6.759853] usb 2-1: Manufacturer: USB 3.0 Device
Mar  1 17:41:30 rpi2 kernel: [    6.759865] usb 2-1: SerialNumber: 000000004BA8
Mar  1 17:41:30 rpi2 kernel: [    6.764241] usb 2-1: WARN: Max Exit Latency too large
Mar  1 17:41:30 rpi2 kernel: [    6.764256] usb 2-1: Could not enable U1 link state, xHCI error -22.
Mar  1 17:41:30 rpi2 kernel: [    6.764869] usb 2-1: UAS is blacklisted for this device, using usb-storage instead
Mar  1 17:41:30 rpi2 kernel: [    6.764957] usb 2-1: UAS is blacklisted for this device, using usb-storage instead
Mar  1 17:41:30 rpi2 kernel: [    6.764970] usb-storage 2-1:1.0: USB Mass Storage device detected
Mar  1 17:41:30 rpi2 kernel: [    6.765552] usb-storage 2-1:1.0: Quirks match for vid 152d pid 0578: 1800000
Mar  1 17:41:30 rpi2 kernel: [    6.765674] scsi host0: usb-storage 2-1:1.0
Mar  1 17:41:31 rpi2 kernel: [    7.769007] scsi 0:0:0:0: Direct-Access     Samsung  SSD 860 QVO 2TB  0301 PQ: 0 ANSI: 6
Mar  1 17:41:31 rpi2 kernel: [    7.771621] sd 0:0:0:0: [sda] 3907029168 512-byte logical blocks: (2.00 TB/1.82 TiB)
Mar  1 17:41:31 rpi2 kernel: [    7.772258] sd 0:0:0:0: [sda] Write Protect is off
Mar  1 17:41:31 rpi2 kernel: [    7.772273] sd 0:0:0:0: [sda] Mode Sense: 47 00 00 08
Mar  1 17:41:31 rpi2 kernel: [    7.772916] sd 0:0:0:0: [sda] Disabling FUA
Mar  1 17:41:31 rpi2 kernel: [    7.772932] sd 0:0:0:0: [sda] Write cache: enabled, read cache: enabled, doesn't support DPO or FUA
Mar  1 17:41:31 rpi2 kernel: [    7.791856] sd 0:0:0:0: Attached scsi generic sg0 type 0
Mar  1 17:41:31 rpi2 kernel: [    7.812862]  sda: sda1
Mar  1 17:41:31 rpi2 kernel: [    7.815164] sd 0:0:0:0: [sda] Attached SCSI disk
```

Note how the quirk matches and thus UAS is disabled. I’m awaiting another USB3–SATA bridge, hopefully with
the ASM1153 chipset which is reported to work well with Linux (cf. [this thread](https://github.com/raspberrypi/linux/issues/3070)).

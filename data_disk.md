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
`/etc/udev/rules/70-data.rules`:

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

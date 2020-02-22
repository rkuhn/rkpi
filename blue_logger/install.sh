#!/bin/bash
cd `dirname $0`
PREFIX=`pwd`
ETC=/etc/systemd/system
LIB=/lib/systemd/system

set -x
test -e $ETC/rfcomm.service && sudo cp $ETC/rfcomm.service{,.bak}
sudo ln -sf $PREFIX/rfcomm.service $ETC
sudo systemctl enable rfcomm
sudo cp $LIB/bluetooth.service{,.bak}
sudo ln -sf $PREFIX/bluetooth.service $LIB
grep PRETTY_HOSTNAME /etc/machine-info 2>/dev/null || (echo PRETTY_HOSTNAME=rpi1 | sudo tee /etc/machine-info)
mkdir -p /home/pi/bin
ln -sf $PREFIX/logger /home/pi/bin
set +x

echo "now is a good time to reboot the system"

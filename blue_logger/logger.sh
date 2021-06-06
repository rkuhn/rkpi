#!/bin/bash
cd /home/pi/log

TOKEN=`date -Ins`
exec </dev/rfcomm0 >>$TOKEN

function DATE() {
  d=`date "+%Y-%m-%dT%H:%M:%S.%N"`
  echo ${d%??????}
}

function sig() {
  echo `DATE` "got signal" "$@"
}
for s in `trap -l | perl -ne 's/\d+\)//g;for(split){print "$_\n"}'`; do
  trap "sig $s" $s
done

echo `DATE` "*** NEW CONNECTION ***"

while read line; do
  echo `DATE` "< $line"
done

echo `DATE` "*** END CONNECTION ***"

# RKπ

This is my collection of things for using [Raspberry
Pi](https://www.raspberrypi.org/).

- `packages` lists some packages that I find useful to install
- `blue_logger` contains some files for capturing logs over bluetooth serial
  connections

## Adding your own dynDNS

Hosting your own dynDNS is easy with Bind9. Create a zone like this:

```
$ORIGIN .
$TTL 60 ; 1 minute
dyn.example.com         IN SOA  ns.example.com. hostmaster.example.com. (
                                2019081787 ; serial
                                600        ; refresh (10 minutes)
                                300        ; retry (5 minutes)
                                604800     ; expire (1 week)
                                600        ; minimum (10 minutes)
                                )
                        NS      ns.example.com.
$ORIGIN dyn.example.com.
```

Add this zone to `/etc/named/named.conf.local` (you are running dnssec, right? RIGHT?):

```
zone "dyn.example.com" {
        type master;
        file "/etc/bind/zones/dyn.example.com";
        auto-dnssec maintain;
        inline-signing yes;
        update-policy {
                <will be filled later>
        };
        notify no;
};
```

Then run the friendly tool `ddns-confgen`, which will kindly explain what you need to do to add a single node:

```
ddns-confgen -s my-rpi.dyn.example.com
```

This will give you the key file to add to your π as well as the section to place in `/etc/named/named.conf.local` and also the line you need to add to the zone’s update-policy to grant the necessary rights. After the customary `rndc reload` we are done on the server side.

Assuming that the keyfile on the π is `/root/ddns.key`, we create the following script in `/root/bin/update_dns.sh`:

```bash
#!/bin/bash

IP=`ip -6 -j a ls | jq -r '.[]|.addr_info|.[]|select(.scope=="global")|.local' | head -1`
NAME=`hostname`

logger -p syslog.notice "updating dynDNS record for $NAME to $IP"

function update() {
nsupdate -k /root/ddns.key <<EOF 2>&1
server ns.example.com
del $NAME.dyn.example.com.
add $NAME.dyn.example.com. 60 IN AAAA $IP
send
answer
EOF
}

answer=`update`
if test $? -ne 0; then
	logger -p syslog.warning "update failed: `echo $answer`"
else
	logger -p syslog.info "update succeeded"
fi
```

and finally activate it by running it every 10min via CRON.

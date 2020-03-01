# Adding your own dynDNS

It is tremendously useful to be able to access your π from anywhere on the internet, and IPv6 makes
this quite easy.

One caveat: your (home) router’s firewall will want to permit only specific IPv6 traffic for your π,
which means that your π will want to have a stable IP address. Since we are talking about a dynamic
environment (else there would be no reason for dynDNS), each time the prefix changes the default
configuration of raspbian will also generate a new address for the lower 64 bits of the IP; this
needs to be disabled by setting `slaac hwaddr` in `/etc/dhcpcd.conf`.

## Server side

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

## Client side

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


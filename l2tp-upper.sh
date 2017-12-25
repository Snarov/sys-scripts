#!/bin/bash

#we have to restart xl2tpd when it stuck on "hostname lookup failed"
if [ ! -d /sys/class/net/ppp0 ] && pgrep xl2tpd > /dev/null; then
    systemctl restart xl2tpd
fi;

#!/bin/bash

PATH=$PATH:/usr/sbin

HARDLIMITED_USERS_FILE=/root/sysscr/cpu-hardlimiter/hardlimited-users
VHOSTS_RESOURCES_DIR=/etc/httpd/conf/vhosts-resources
HARDLIMTED_CONF_FILE=/root/sysscr/cpu-hardlimiter/hardlimited.conf

cpu_usage_limits[500]=14
cpu_usage_limits[1000]=36
cpu_usage_limits[5000]=58
cpu_usage_limits[10000]=86
cpu_usage_limits[20000]=144
cpu_usage_limits[40000]=216

cat $HARDLIMITED_USERS_FILE | while read username; do
    
    cpu_usage_limit=${cpu_usage_limits[`/usr/local/mgr5/sbin/mgrctl -m ispmgr user.edit elid=$username | fgrep limit_quota= | cut -f2 -d '='`]}
    current_cpu_usage=`sa -m | fgrep "$username " | awk '{print $4}' | tr -d "cp"`
    if [ -z $current_cpu_usage ]; then
	continue
    fi

    apache_conf_file="$VHOSTS_RESOURCES_DIR/$username/hardlimited.conf"
    vhost_resources_dir="$VHOSTS_RESOURCES_DIR/$username"
    
    if [ `echo $current_cpu_usage'>'$cpu_usage_limit | bc -l` -eq 1 ]; then
	#if cpu usage limit reached
	if [ ! -f $apache_conf_file ]; then
	    if [ ! -d $vhost_resources_dir ]; then
		mkdir $vhost_resources_dir
	    fi
	    
	    cp $HARDLIMTED_CONF_FILE $vhost_resources_dir
	    systemctl reload httpd
	fi
    else
	#if stats are wiped
	if [ -f $apache_conf_file ]; then
	    rm $apache_conf_file
	    systemctl reload httpd
	fi
    fi
done

#!/bin/bash

cpu_usage_limits[500]=14
cpu_usage_limits[1000]=36
cpu_usage_limits[5000]=58
cpu_usage_limits[10000]=86
cpu_usage_limits[20000]=144
cpu_usage_limits[40000]=216


/usr/local/mgr5/sbin/mgrctl -m ispmgr user > /tmp/isp_users.tmp

echo "`sa -m $1`" | while read row; do
    username=`echo $row | cut -f 1 -d ' '`
    cpu_usage=`echo $row | awk '{print $4}' | tr -d "cp"`
    
    if [ -d "/var/www/$username/data/logs/" ]; then
	all_cpu_usage_ps=`echo "$cpu_usage * 100 / 1440 " | bc`
	tariff_id=`cat /tmp/isp_users.tmp | fgrep "name=$username " | grep -o "quota_total=[0-9]*" | cut -f 2 -d =`
	allowable_cpu_usage_ps=`echo "$cpu_usage * 100 / ${cpu_usage_limits[$tariff_id]}" | bc`

	echo "[$2] Пользователь: $username" >>  "/var/www/$username/data/logs/cpu-usage.log"
	echo "Использование CPU: ${all_cpu_usage_ps}% (${cpu_usage}cp)" >> "/var/www/$username/data/logs/cpu-usage.log"
	echo "Всего использовано CPU по отношению к лимиту: $allowable_cpu_usage_ps %" >> "/var/www/$username/data/logs/cpu-usage.log"
	exit
    fi
done

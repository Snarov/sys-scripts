#!/bin/bash

source `dirname $0`/etc/config.sh

#Собирает почасовую статистику использования внутреннего траффика и вносит соответствующие корректировки в БД VMManager

function get_vm_ids {
    /usr/local/mgr5/sbin/mgrctl -m vmmgr vm | cut -f 1 -d ' ' | cut -f 2 -d '=' | while read id; do echo $id; done
}

function get_vm_name {
    /usr/local/mgr5/sbin/mgrctl -m vmmgr vm.edit elid=$1 | grep '^name=' | cut -f2 -d '='
}

function get_vm_bridge {
    /usr/local/mgr5/sbin/mgrctl -m vmmgr vm.sysinfo elid=$1 | egrep -o "vnet[[:digit:]]+"
}

: > $STATHR_FILE

for id in `get_vm_ids`; do
    vm_bridge=`get_vm_bridge $id`
    
    by_rx=`iptables -nvx -L TRAFFIC_ACCT_IN | grep "$vm_bridge\$" | sed 's/^[[:blank:]]*//' | tr -s [:blank:] | cut -d' ' -f2`
    by_prx=`iptables -nvx -L TRAFFIC_ACCT_IN | grep "$vm_bridge\$" | sed 's/^[[:blank:]]*//'  | tr -s [:blank:] | cut -d' ' -f1`
    
    by_tx=`iptables -nvx -L TRAFFIC_ACCT_OUT | grep "$vm_bridge\$" | sed 's/^[[:blank:]]*//' | tr -s [:blank:] | cut -d' ' -f2`
    by_ptx=`iptables -nvx -L TRAFFIC_ACCT_OUT | grep "$vm_bridge\$" | sed 's/^[[:blank:]]*//' | tr -s [:blank:] | cut -d' ' -f1`

    vm_name=`get_vm_name $id`
    #Начало предыдущего часа
    hr_begin=$((`date +%s` / 3600 * 3600 - 3600))

    #Формат: <имя машины> <in_bytes> <in_packets> <out_bytes> <out_packets>
    echo "$vm_name $by_rx $by_prx $by_tx $by_ptx" >> $STATHR_FILE

done

iptables -Z

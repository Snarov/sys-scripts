#!/bin/bash
#Обновляет список внутренних адресов, если он изменился

FREE_SUBNETS_LIST_URL='https://noc.datahata.by/free.txt'
FREE_SUBNETS_LIST_FILE='etc/free-subnets'

function get_subnets_list {
    subnets_list=''
    while read subnet; do
	subnets_list="$subnets_list,$subnet"
    done < $1

    subnets_list=${subnets_list#?};
}

wget -O $FREE_SUBNETS_LIST_FILE-tmp $FREE_SUBNETS_LIST_URL &>/dev/null

diff $FREE_SUBNETS_LIST_FILE-tmp $FREE_SUBNETS_LIST_FILE &>/dev/null

if [ $? -ne 0 ]; then
    get_subnets_list $FREE_SUBNETS_LIST_FILE
    iptables -D FORWARD -d $subnets_list -j TRAFFIC_ACCT_OUT
    iptables -D FORWARD -s $subnets_list -j TRAFFIC_ACCT_IN

    get_subnets_list $FREE_SUBNETS_LIST_FILE-tmp
    iptables -I FORWARD -d $subnets_list -j TRAFFIC_ACCT_OUT
    iptables -I FORWARD -s $subnets_list -j TRAFFIC_ACCT_IN

    cp $FREE_SUBNETS_LIST_FILE-tmp $FREE_SUBNETS_LIST_FILE
fi

rm $FREE_SUBNETS_LIST_FILE-tmp

iptables-save > /etc/sysconfig/iptables

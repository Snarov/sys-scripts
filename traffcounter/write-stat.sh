#!/bin/bash

#Записывает ранее собранную статистику в БД VMManager
source `dirname $0`/etc/config.sh

while read vm_stat; do
    vm_name=`echo $vm_stat | cut -f 1 -d ' '`

    by_rx=`echo $vm_stat | cut -f 2 -d ' '`
    by_prx=`echo $vm_stat | cut -f 3 -d ' '`

    by_tx=`echo $vm_stat | cut -f 4 -d ' '`
    by_ptx=`echo $vm_stat | cut -f 5 -d ' '`

    #Начало часа
    hr_begin=$((`date +%s` / 3600 * 3600 - 3600))

    #Если VMmanager еще не собрал статистику, то ждем, пока он это сделает
    while [[ -z `mysql vmmgr -e "SELECT count FROM stathr WHERE vm='$vm_name' AND begin=$hr_begin"` ]]; do
        sleep 1;
    done

    mysql vmmgr -e "UPDATE stathr SET rx = 0 WHERE rx < $by_rx AND vm='$vm_name' AND begin=$hr_begin"
    mysql vmmgr -e "UPDATE stathr SET prx = 0 WHERE  prx < $by_prx AND  vm='$vm_name' AND begin=$hr_begin"
    mysql vmmgr -e "UPDATE stathr SET tx = 0 WHERE tx < $by_tx AND vm='$vm_name' AND begin=$hr_begin"
    mysql vmmgr -e "UPDATE stathr SET ptx = 0 WHERE ptx < $by_ptx AND  vm='$vm_name' AND begin=$hr_begin"

    mysql vmmgr -e "UPDATE stathr SET rx = rx - $by_rx WHERE rx >= $by_rx AND vm='$vm_name' AND begin=$hr_begin"
    mysql vmmgr -e "UPDATE stathr SET prx = prx - $by_prx WHERE prx >= $by_prx AND  vm='$vm_name' AND begin=$hr_begin"
    mysql vmmgr -e "UPDATE stathr SET tx = tx - $by_tx WHERE tx >= $by_tx AND vm='$vm_name' AND begin=$hr_begin"
    mysql vmmgr -e "UPDATE stathr SET ptx = ptx - $by_ptx WHERE ptx >= $by_ptx AND  vm='$vm_name' AND begin=$hr_begin"
done < $STATHR_FILE


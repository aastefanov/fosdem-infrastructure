#!/bin/bash

nagioshost=188.34.182.16

hst=`hostname`


diskchk=`/usr/lib/nagios/plugins/check_disk -u GB -X tmpfs -e -w 4% -c 1% ` 
diskchk_ret=$?


output=$output"$hst\tdisk\t$diskchk_ret\t$diskchk\n\027"

ncpu=`grep ^processor /proc/cpuinfo  |wc -l`

w=`echo "$ncpu*2.10"|bc`
c=`echo "$ncpu*2.40"|bc`

smax=`echo "$ncpu*10"|bc`


w15=`echo "$ncpu*1.80"|bc`
c15=`echo "$ncpu*2.00"|bc`

loadchk=`/usr/lib/nagios/plugins/check_load -w $smax,$w,$w15 -c $smax,$c,$c15`
loadchk_ret=$?

output=$output"$hst\tload\t$loadchk_ret\t$loadchk\n\027" 

ret=0

live=""
dead=""

daemons="sshd chronyd"

if $(hostname |grep -q vocto) ; then
        daemons=$daemons" voctocore.py sink-output.sh source-slide.sh"
fi

if ! $(hostname |grep -q streamdump) ; then
        daemons=$daemons" nginx"
fi
for daemon in $daemons; do
        if ps auxwf |grep -v grep |grep -w $daemon > /dev/null; then
                live=$live" "$daemon    
        else
                dead=$dead" "$daemon
        fi
done

if [ -z "$dead" ]; then
        chk="OK, live $live"
        ret=0
else
        chk="CRITICAL: dead: $dead; live: $live"
        ret=2
fi
output=$output"$hst\tdaemons\t$ret\t$chk\n\027"            


for i in `seq 1 10`; do
        /bin/echo -ne "$output" | /usr/sbin/send_nsca -c /etc/send_nsca.cfg -H $nagioshost  >/dev/null 2>/dev/null
        if [ $? -eq 0 ]; then
                break
        fi
        sleep $i
done

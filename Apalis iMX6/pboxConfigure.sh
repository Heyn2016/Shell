#!/bin/sh
#--------------------------------------------
# Platform: ARM Linux
# Author:   Heyn
#
# History:  2017/02/22 V1.0.1[Heyn]
#
#--------------------------------------------

#--------------------------------------------
# User config start
#--------------------------------------------

webpath=/www/pages/htdocs/conf/AnyLink.xml
confpath=/tmp/pboxConfig

ltemodulename="usb0"
netmode="gateway"
cloudaddr="47.93.79.77"

#--------------------------------------------
# User config end
#--------------------------------------------

echo "netmode="$netmode      >   $confpath
echo "cloudaddr="$serveraddr >>  $confpath

if [ ! -f "$webpath" ]; then
    echo $webpath file is not exist.
    exit 0
fi

#--------------------------------------------
# Get network mode
#--------------------------------------------

while read lines
do
    item=`echo $lines | awk -F['>'] '/\<Mode\>/{print $2}' | awk -F['<'] '{print $1}'`
    if [ "$item" == "4G" ];then
        netmode=$item
        break
    elif [ "$item" == "gateway" ];then
        netmode=$item
        break
    fi
done<$webpath


#--------------------------------------------
# Check LTE module
#--------------------------------------------

for num  in 0 1 2 3 4
do
    if [ ! -c "/dev/ttyUSB$num" ]; then
        echo HUAWEI LTE Module is not exist.
        exit 0
    fi
done

#--------------------------------------------
# Get cloud ip address
#--------------------------------------------
cat $webpath |awk -F['>'] '/\<CloudInfo\>/{print $3}'|while read line

do
    cloudaddr=`echo $line | awk -F['<'] '{print $1}'`
done

# Debug
#netmode="4G"

echo "netmode="$netmode     >   $confpath
echo "cloudaddr="$cloudaddr >>  $confpath

timesyncpath=/etc/systemd/timesyncd.conf
echo "[Time]"    > $timesyncpath
echo "NTP=$cloudaddr" >> $timesyncpath
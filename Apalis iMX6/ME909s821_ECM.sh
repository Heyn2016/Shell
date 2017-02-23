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
ltemodulename="usb0"

#--------------------------------------------
# User config end
#--------------------------------------------


if [ ! -f "$webpath" ]; then
    echo $webpath file is not exist.
    exit 0
fi

#--------------------------------------------
# Get network mode
#--------------------------------------------
netmode="gateway"

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


# Debug
#netmode="4G"


if [ "$netmode" == "4G" ];then
    echo Start LTE connection...
    # HUAWEI ME909s Series LTE Module
    # Do not blink. (default value)
    echo -e "AT^LEDCTRL=1\r\n" > /dev/ttyUSB0
    echo -e "AT^NDISDUP=1,1\r\n" > /dev/ttyUSB0
    udhcpc -i $ltemodulename
else
    echo Wired connection...
    exit 0
fi


address=$(ip addr show label $ltemodulename scope global | awk '$1 == "inet" { print $2,$4}')

# ip address
ip=$(echo $address | awk '{print $1 }')
ip=${ip%%/*}

# broadcast
broadcast=$(echo $address | awk '{print $2 }')

# mask address
mask=$(route -n |grep 'U[ \t]' | head -n 1 | awk '{print $3}')

# gateway address
gateway=$(route -n | grep 'UG[ \t]' | grep $ltemodulename | awk '{print $2}')

# dns
dns=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')


echo ip:$ip,mask:$mask,broadcast:$broadcast,gateway:$gateway,dns:$dns

if [ "$ip" == "" ];then
    echo HUAWEI LTE Module dial failure.
    exit 1
fi

# Get cloud ip address

cat $webpath |awk -F['>'] '/\<CloudInfo\>/{print $3}'|while read line

do
    cloudaddr=`echo $line | awk -F['<'] '{print $1}'`
    
    if [ "$(route -n | grep $cloudaddr)" == "" ];then
        echo Cloud IP Address = $cloudaddr
        route add -net $cloudaddr netmask 255.255.255.255 dev $ltemodulename
    fi
done



#!/bin/sh
#--------------------------------------------
# Platform: ARM Linux
# Author:   Heyn
#
# History:  2017/03/10 V1.0.0[Heyn]
#
#--------------------------------------------

array_ip=("192.168.5.1" "47.93.79.77")

logfile=/tmp/pbox_daemon.log

#--------------------------------------------
# User config start
#--------------------------------------------

webpath=/www/pages/htdocs/conf/AnyLink.xml

if [ ! -f "$webpath" ]; then
    echo $webpath file is not exist. >> $logfile
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
done < $webpath


if [ "$netmode" == "gateway" ];then
    echo Wired connection... >> $logfile
    exit 0
fi

# 1 packets transmitted, 1 packets received, 0% packet loss
# 1 packets transmitted, 0 packets received, 100% packet loss

# netstatus=0
# for ip in ${array_ip[@]}
# do
#     ping=`ping -c 1 $ip|grep loss|awk '{print $7}'|awk -F "%" '{print $1}'`

#     if [ $ping -eq 100  ];then
#         # echo ping $ip fail
#          netstatus=$[$netstatus-1]
#     else
#         # echo ping $ip ok
#         netstatus=$[$netstatus+1]
#     fi
# done

# if [ "$netstatus" == "${#array_ip[@]}" ];then
#     echo Net Status is online...
#     exit 0
# fi

#--------------------------------------------
# Query the Connection Status
#--------------------------------------------
echo -e "AT\r\n" > /dev/ttyUSB0

# Response:^NDISSTATQRY: 0,,,"IPV4",0,,,"IPV6"
while read lines
do
    if [[ "$lines" == *"^NDISSTATQRY:"* ]];then
        res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $1}')
        if [ "$res" == "1" ];then
            echo Net Status is online...
            exit 0
        else
            echo Disconnected Done
            break
        fi
    fi
    echo -e "AT^NDISSTATQRY?\r\n" > /dev/ttyUSB0
done < /dev/ttyUSB0
#--------------------------------------------
# Query the Connection Status Done
#--------------------------------------------

echo 4G Status [Offline]: `date '+%Y-%m-%d %H:%M:%S'`

echo Start 4G connection...
echo -e "AT\r\n" > /dev/ttyUSB0
echo -e "AT^NDISDUP=1,1\r\n" > /dev/ttyUSB0

udhcpc -i usb0

#!/bin/sh
#--------------------------------------------
# Platform: ARM Linux
# Author:   Heyn
#
# History:  2017/03/10 V1.0.0[Heyn]
#           2017/03/13 V1.0.1[Heyn] Add shell input parameter function
#           2017/03/16 V1.0.2[heyn] Release
#
# systemctl status pboxScript
#--------------------------------------------

array_ip=("192.168.5.1" "47.93.79.77")

#--------------------------------------------
# User config start
#--------------------------------------------

logfile=/tmp/lte_daemon.log
confpath=/tmp/pboxConfig


if [ ! -f "$logfile" ]; then
    echo `date '+%Y-%m-%d %H:%M:%S'` >> $logfile
fi

if [ `expr match $1 "[S|s][T|t][O|o][P|p]$"` -ne 0 ]; then
    echo -e "AT^NDISDUP=1,0\r\n" > /dev/ttyUSB0
    echo 4G Status [Offline]: `date '+%Y-%m-%d %H:%M:%S'` >> $logfile
    exit 0
fi

if [ ! -f "$confpath" ]; then
    echo $confpath file is not exist. > $logfile
    exit 0
fi

#--------------------------------------------
# Get network mode
#--------------------------------------------
netmode="gateway"

while read lines
do
    item=`echo $lines | awk -F['='] '{print $1}'`
    if [ "$item" == "netmode" ];then
        netmode=`echo $lines | awk -F['='] '{print $2}'`
    elif [ "$item" == "cloudaddr" ];then
        cloudaddr=`echo $lines | awk -F['='] '{print $2}'`
    fi
done < $confpath


if [ "$netmode" == "gateway" ];then
    echo Wired connection...
    echo `systemctl stop cora.timer`
    exit 0
fi

echo Wireless connection...
# if [ "$(echo `date '+%H%M'`)" -gt "0700" ]; then
#     echo "Offline time. [0700 - 2359]" `date '+%Y-%m-%d %H:%M'`
#     exit 0
# fi


#--------------------------------------------
# Query the Connection Status
#--------------------------------------------
echo -e "AT\r\n" > /dev/ttyUSB0
echo -e "AT^NDISSTATQRY?\r\n" > /dev/ttyUSB0
# Response:^NDISSTATQRY: 0,,,"IPV4",0,,,"IPV6"
while read lines
do
    if [[ "$lines" == *"^NDISSTATQRY:"* ]];then
        res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $1}')
        if [ "$res" == "1" ];then
            echo Net Status is online...
            exit 0
        else
            break
        fi
    fi
    echo -e "AT^NDISSTATQRY?\r\n" > /dev/ttyUSB0
done < /dev/ttyUSB0
#--------------------------------------------
# Query the Connection Status Done
#--------------------------------------------
echo Start Detect SIM Card...
#--------------------------------------------
# Detect SIM Card
#--------------------------------------------

srv_status=("No services" "Restricted services" "Valid services" "Restricted regional services" "Power saving or hibernate state")
srv_domain=("No services" "CS service only" "PS service only" "PS+CS services" "Not registered to CS or PS; searching now")
roam_status=("Not roaming" "Roaming")
sim_state=("Invalid SIM card" "Valid SIM card" "Invalid SIM card in CS" "Invalid SIM card in PS" "Invalid SIM card in PS and CS" "ROMSIM version" "No SIM card is found")
lock_state=("SIM card is not locked by the CardLock feature." "SIM card is locked by the CardLock feature.")
sysmode=("NO SERVICE" "GSM" "CDMA" "WCDMA" "TD-SCDMA" "WiMAX" "LTE")

# [ERROR] ^SYSINFOEX: 1,0,0,4,,3,"WCDMA",41,"WCDMA  
echo -e "AT\r\n" > /dev/ttyUSB0
echo -e "AT^SYSINFOEX\r\n" > /dev/ttyUSB0
while read lines
do
    if [[ "$lines" == *"^SYSINFOEX:"* ]];then
        # <srv_status>: indicates the system service status.
        res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $1}')
        if [ "$res" != "2" ];then
            echo ${srv_status[$res]}
            exit 0
        fi
        # <sim_state>: indicates the state of the SIM card.
        res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $4}')
        if [ "$res" != "1" ];then
            echo ${sim_state[$res]}
            exit 0
        fi

        break 
    fi
    echo -e "AT^SYSINFOEX\r\n" > /dev/ttyUSB0
done < /dev/ttyUSB0

echo Start 4G connection...
echo -e "AT\r\n" > /dev/ttyUSB0
echo -e "AT^NDISDUP=1,1\r\n" > /dev/ttyUSB0
sleep 2s

# udhcpc -R -n -A 15 -i usb0
udhcpc -i usb0

# Get cloud ip address
if [ "$(route -n | grep $cloudaddr)" == "" ];then
    # echo Cloud IP Address = $cloudaddr >> $logfile
    route add -net $cloudaddr netmask 255.255.255.255 dev usb0
fi

echo 4G Status [Online ]: `date '+%Y-%m-%d %H:%M:%S'` >> $logfile


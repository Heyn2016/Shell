#!/bin/sh
#--------------------------------------------
# Platform: ARM Linux
# Author:   Heyn
#
# History:  2017/03/10 V1.0.0[Heyn]
#           2017/03/13 V1.0.1[Heyn] Add shell input parameter function
#           2017/03/16 V1.0.2[heyn] Release
#           2017/03/17 V1.1.0[heyn] stty -F /dev/ttyUSB0 raw speed 9600 min 0 time 10
#           2017/03/20 V1.1.1[heyn] New HUAWEI module LEDCTRL ON/OFF
#           2017/03/22 V1.2.0[heyn] Modify Query the Connection Status. Changed ttyUSB0 to ttyUSB2
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
    echo -e "AT^LEDCTRL=0\r\n" > /dev/ttyUSB2
    echo -e "AT^NDISDUP=1,0\r\n" > /dev/ttyUSB2
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
    echo -e "AT^LEDCTRL=0\r\n" > /dev/ttyUSB2
    echo `systemctl stop cora.timer`
    exit 0
fi

echo Wireless connection...
echo -e "AT\r\n" > /dev/ttyUSB2
echo -e "AT^LEDCTRL=1\r\n" > /dev/ttyUSB2

# if [ "$(echo `date '+%H%M'`)" -gt "0700" ]; then
#     echo "Offline time. [0700 - 2359]" `date '+%Y-%m-%d %H:%M'`
#     exit 0
# fi

stty -F /dev/ttyUSB2 raw speed 9600 min 0 time 10
# stty -F /dev/ttyUSB2 raw min 0 time 10

#--------------------------------------------
# Query the Connection Status
# Response:^NDISSTATQRY: 0,,,"IPV4",0,,,"IPV6"
#--------------------------------------------
echo Start query connection status...

for num  in {0..2}
do
    echo -e "AT^NDISSTATQRY?\r\n" > /dev/ttyUSB2
    cat /dev/ttyUSB2 > /tmp/huawei
    res=`cat /tmp/huawei | grep '\^NDISSTATQRY:' | awk '{print $2}' | awk -F[','] '{print $1}'`
    if [ "$res" == "1" ];then
        echo Net status is online...
        exit 0
    elif [ "$res" == "0" ];then
        break
    else
        echo Retrt query connection status [$num]
        if [ "$num" == "2" ];then
            exit -1
        fi
    fi
done

#--------------------------------------------
# Query the Connection Status Done
#--------------------------------------------


#--------------------------------------------
# Query Domain Registration Status
#--------------------------------------------
cgreg_status=(  "Not registered, MT is not currently searching for a new operator to register with." 
                "Registered, home network" 
                "Not registered, but MT is currently searching a new operator to register with." 
                "Registration denied" 
                "Unknown" 
                "Registered, roaming" 
            )

echo Start domain registration status...
echo -e "AT\r\n" > /dev/ttyUSB2
echo -e "AT+CGREG?\r\n" > /dev/ttyUSB2
cat /dev/ttyUSB2 > /tmp/huawei
# Response : +CGREG: 0,1
while read lines
do
    if [[ "$lines" == *"CGREG"* ]];then
        res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $2}')
        
        if [ "$res" == "1" ] || [ "$res" == "5" ];then
            echo $lines
            echo ${cgreg_status[$res]}
            break
        elif [ "$res" == "0" ] || [ "$res" == "2" ] || [ "$res" == "3" ];then
            echo ${cgreg_status[$res]} >> $logfile
            sleep 1s
        else
            # cgreg_status = Unknown
            echo Unknown >> $logfile
            exit 1
        fi
    fi
done < /tmp/huawei


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
echo Start detect SIM card...

echo -e "AT^SYSINFOEX\r\n" > /dev/ttyUSB2
cat /dev/ttyUSB2 > /tmp/huawei

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
done < /tmp/huawei


echo Start 4G connection...

echo -e "AT\r\n" > /dev/ttyUSB2
echo -e "AT^NDISDUP=1,1\r\n" > /dev/ttyUSB2
sleep 2s

# udhcpc -R -n -A 15 -i usb0
udhcpc -n -i usb0


# Get cloud ip address
if [ "$(route -n | grep $cloudaddr)" == "" ];then
    # echo Cloud IP Address = $cloudaddr >> $logfile
    route add -net $cloudaddr netmask 255.255.255.255 dev usb0
fi

echo 4G Status [Online ]: `date '+%Y-%m-%d %H:%M:%S'` >> $logfile

echo -e "AT^LEDCTRL=1\r\n" > /dev/ttyUSB2

# PID=`ps -ef | grep -v grep | grep "cat" | grep "ttyUSB2" | awk '{ print $2; exit }'`

# if test $PID; then
#         kill -KILL $PID

#         if [ ! "$?" = "0" ]; then
#                 echo "ERROR: Terminated failed"
#                 exit 3
#         fi

#         echo "link terminated"
#         exit 0
# fi
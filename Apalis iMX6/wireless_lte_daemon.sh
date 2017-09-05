#!/bin/sh
#--------------------------------------------
# Platform: ARM Linux
# Author:   Heyn
#
# History:  2017/03/10 V1.0.0 [Heyn] New
#           2017/03/13 V1.0.1 [Heyn] Add shell input parameter function
#           2017/03/16 V1.0.2 [Heyn] Release
#           2017/03/17 V1.1.0 [Heyn] stty -F /dev/ttyUSB0 raw speed 9600 min 0 time 10
#           2017/03/20 V1.1.1 [Heyn] New HUAWEI module LEDCTRL ON/OFF
#           2017/03/22 V1.2.0 [Heyn] Modify Query the Connection Status. Changed ttyUSB0 to ttyUSB2
#           2017/04/19 V1.2.1 [Heyn] Fixed Bug#89 ption1 ttyUSB0: usb_wwan_indat_callback: resubmit read urb failed.
#           2017/05/25 V1.2.2 [Heyn] Optimized code.
#
# systemctl status wireless_lte
#--------------------------------------------

#--------------------------------------------
# User config start
#--------------------------------------------

ltelogs=/tmp/modulelogs
confpath=/tmp/pboxConfig
dialnum=/tmp/dialnum
atport=/dev/ttyUSB2


#--------------------------------------------
# Check if the log file exists
#--------------------------------------------
if [ ! -f "$ltelogs" ]; then
    echo 4G Status [PowerOn]: `date '+%Y-%m-%d %H:%M:%S'` > $ltelogs
fi

if [ $# == 1 ] && [ `expr match $1 "[S|s][T|t][O|o][P|p]$"` -ne 0 ]; then
    echo -e "AT^LEDCTRL=0\r\n"   >> $atport ; echo -e "AT^NDISDUP=1,0\r\n" >> $atport
    echo 4G Status [Offline]: `date '+%Y-%m-%d %H:%M:%S'` >> $ltelogs
    exit 0
elif [ $# == 1 ] && [ `expr match $1 "[S|s][T|t][A|a][R|r][T|t]$"` -ne 0 ]; then
    echo [Step 0] `date '+%Y-%m-%d %H:%M:%S'`
else
    echo "Input param error. [stop or start]" ; exit 0
fi

#--------------------------------------------
# Check if the pbox configure file exists
#--------------------------------------------
if [ ! -f "$confpath" ]; then
    echo $confpath file is not exist. > $ltelogs ; echo `systemctl stop cora.timer`
    exit 0
fi

#--------------------------------------------
# Get network mode
#--------------------------------------------
netmode="gateway"
cloudaddr="47.93.79.77"

while read lines
do
    item=`echo $lines | awk -F['='] '{print $1}'`
    if [ "$item" == "netmode" ]; then
        netmode=`echo $lines | awk -F['='] '{print $2}'`
    elif [ "$item" == "cloudaddr" ]; then
        cloudaddr=`echo $lines | awk -F['='] '{print $2}'`
    fi
done < $confpath


if [ "$netmode" == "gateway" ]; then
    echo Wired connection...
    echo -e "AT^LEDCTRL=0\r\n" >> $atport ; echo `systemctl stop cora.timer`
    exit 0
fi

#--------------------------------------------
# Check LTE module
# 2017/05/25 V1.2.2 [Heyn] Optimized code.
#--------------------------------------------

if [ $(lsusb | grep 'Huawei' | awk '{print $6}' | awk -F[':'] '{print $1 $2}') != "12d115c1" ]; then
    echo `date '+%Y-%m-%d %H:%M:%S'` HUAWEI ME909s-821 Module not detected. >> $ltelogs
    exit 0
else
    portArray=()
    index=0
    for port  in `ls /dev/ttyUSB*`
    do
        if [ ! -c $port ]; then
            echo `date '+%Y-%m-%d %H:%M:%S'` HUAWEI LTE Module [$port] not exist. >> $ltelogs
            echo -e `rm -rf $port`
        else
            stty -F $port raw min 0 time 5 ; echo -e "ATE0\r\n" >> $port 
            if [[ `cat $port` == *"OK"* ]]; then
                portArray[index]=$port ; index=$(($index+1))
            fi
        fi
    done

    if [ ${#portArray[*]} > 0 ]; then
        atport=${portArray[${#portArray[*]}-1]}
    else
        echo `date '+%Y-%m-%d %H:%M:%S'` HUAWEI LTE Module [$port] not detected. >> $ltelogs
        exit 0
    fi
fi

echo [Step 1] `date '+%Y-%m-%d %H:%M:%S'`

echo Wireless connection on $atport
# stty -F $atport raw min 0 time 10

# echo -e "AT\r\n"         >> $atport | cat $atport > /dev/null
# echo -e "ATE0\r\n"       >> $atport | cat $atport > /dev/null     # Close ECHO
# echo -e "AT^CURC=0\r\n"  >> $atport | cat $atport > /dev/null     # Close part of the initiative to report, such as signal strength of the report
# echo -e "AT^STSF=0\r\n"  >> $atport | cat $atport > /dev/null     # Close the STK's active reporting
# echo -e "ATS0=0\r\n"     >> $atport | cat $atport > /dev/null     # Turn off auto answer
# echo -e "AT+CGREG=2\r\n" >> $atport | cat $atport > /dev/null     # Open the PS domain registration status changes when the active reporting function
# echo -e "AT+CMEE=2\r\n"  >> $atport | cat $atport > /dev/null     # When the error occurs, the details are displayed

#--------------------------------------------
# Query the Connection Status
# Response:^NDISSTATQRY: 0,,,"IPV4",0,,,"IPV6"
#--------------------------------------------
echo Start query connection status...

for loopnum  in {0..2}
do
    res="255"
    echo -e "AT^NDISSTATQRY?\r\n" >> $atport
    res=$(echo `cat $atport | grep NDISSTATQRY: | awk '{print $2}' | awk -F[','] '{print $1}'`)
    if [ "$res" == "1" ]; then
        echo "0"   >   $dialnum
        echo Net status is online...
        exit 0
    elif [ "$res" == "0" ]; then
        break
    else
        echo Retrt query connection status [$loopnum]
        if [ "$loopnum" == "2" ]; then
            exit -1
        fi
    fi
done

echo [Step 2] `date '+%Y-%m-%d %H:%M:%S'`

# for num  in {0..2}
# do
#     loopnum=0
#     echo -e "AT\r\n" > $atport; echo -e "AT^NDISSTATQRY?\r\n" > $atport
#     while read lines
#     do
#         if [[ "$lines" == *"^NDISSTATQRY:"* ]]; then
#             res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $1}')
#             if [ "$res" == "1" ]; then
#                 echo Net status is online...[$num]
#                 exit 0
#             elif [ "$res" == "0" ]; then
#                 break
#             else
#                 echo Retrt query connection status.
#                 exit -1
#             fi
#         fi

#         # Exception
#         loopnum=$(($loopnum+1))
#         if [ "$loopnum" -ge 100 ]; then
#             echo `date '+%Y-%m-%d %H:%M:%S'` HUAWEI ME909s-821 Module exception. >> $ltelogs
#             echo -e "AT^RESET\r\n" >> /dev/ttyUSB0
#             exit 0
#         fi
#     done < $atport

#     # It's offline status.
#     if [ "$res" == "0" ]; then
#         break
#     fi
# done

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
echo -e "AT\r\n" >> $atport ; echo -e "AT+CGREG?\r\n" >> $atport ; cat $atport > /tmp/huawei
# Response : +CGREG: 0,1
while read lines
do
    if [[ "$lines" == *"CGREG"* ]]; then
        res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $2}')
        if [ "$res" == "1" ] || [ "$res" == "5" ]; then
            echo ${cgreg_status[$res]}
            break
        elif [ "$res" == "0" ] || [ "$res" == "2" ] || [ "$res" == "3" ]; then
            echo `date '+%Y-%m-%d %H:%M:%S'` ${cgreg_status[$res]} >> $ltelogs
            exit 1
        else
            echo `date '+%Y-%m-%d %H:%M:%S'` >> $ltelogs
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
echo -e "AT^SYSINFOEX\r\n" >> $atport ; cat $atport >> /tmp/huawei

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

echo -e "AT\r\n" >> $atport ; echo -e "AT^NDISDUP=1,1\r\n" >> $atport

#--------------------------------------------
count=$(cat $dialnum)
count=$(($count+1))
if [ "$count" -ge 3 ]; then
    echo "0"   >   $dialnum
    echo -e "AT^RESET\r\n" >> /dev/ttyUSB0
    exit 0
fi
echo $count   >   $dialnum
#--------------------------------------------

sleep 2s
udhcpc -n -i usb0

# Get cloud ip address
if [ "$(route -n | grep $cloudaddr)" == "" ];then
    route add -net $cloudaddr netmask 255.255.255.255 dev usb0
fi

echo -e "AT^LEDCTRL=1\r\n" >> $atport
echo 4G Status [Online ]: `date '+%Y-%m-%d %H:%M:%S'` >> $ltelogs

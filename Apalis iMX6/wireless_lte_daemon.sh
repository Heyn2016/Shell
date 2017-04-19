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

# systemctl status wireless_lte
#--------------------------------------------

#--------------------------------------------
# User config start
#--------------------------------------------

logfile=/tmp/lte_daemon.log
confpath=/tmp/pboxConfig
dialnum=/tmp/dialnum
ATDEV=/dev/ttyUSB2

if [ ! -f "$logfile" ]; then
    echo `date '+%Y-%m-%d %H:%M:%S'` >> $logfile
fi

if [ `expr match $1 "[S|s][T|t][O|o][P|p]$"` -ne 0 ]; then
    echo -e "AT^LEDCTRL=0\r\n" >> $ATDEV
    echo -e "AT^NDISDUP=1,0\r\n" >> $ATDEV
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
    elif [ "$item" == "init" ];then
        init=`echo $lines | awk -F['='] '{print $2}'`
    fi
done < $confpath


if [ "$netmode" == "gateway" ];then
    echo Wired connection...
    echo -e "AT^LEDCTRL=0\r\n" >> $ATDEV
    echo `systemctl stop cora.timer`
    exit 0
fi

#--------------------------------------------
# Check LTE module
#--------------------------------------------
vidpid=$(lsusb | grep 'Huawei' | awk '{print $6}' | awk -F[':'] '{print $1 $2}')
if [ "$vidpid" != "12d115c1" ];then
    echo HUAWEI ME909s-821 Module not detected.
    exit 0
fi

for num  in 0 1 2 3 4
do
    if [ ! -c "/dev/ttyUSB$num" ]; then
        echo HUAWEI LTE Module [$num] is not exist.
        echo -e `rm -rf /dev/ttyUSB$num`
        echo -e "AT^RESET\r\n" >> /dev/ttyUSB0
        exit 0
    fi
done

stty -F $ATDEV raw speed 9600 min 0 time 20

echo -e "AT\r\n"        >> $ATDEV
echo -e "ATE0\r\n"      >> $ATDEV      # Close ECHO
echo -e "AT^CURC=0\r\n" >> $ATDEV      # Close part of the initiative to report, such as signal strength of the report
echo -e "AT^STSF=0\r\n" >> $ATDEV      # Close the STK's active reporting
echo -e "ATS0=0\r\n"    >> $ATDEV      # Turn off auto answer
echo -e "AT+CGREG=2\r\n" >> $ATDEV     # Open the PS domain registration status changes when the active reporting function
echo -e "AT+CMEE=2\r\n" >> $ATDEV      # When the error occurs, the details are displayed

echo Wireless connection...
# echo -e "AT\r\n" >> $ATDEV
# echo -e "AT^LEDCTRL=1\r\n" >> $ATDEV

#--------------------------------------------
# Query the Connection Status
# Response:^NDISSTATQRY: 0,,,"IPV4",0,,,"IPV6"
#--------------------------------------------
echo Start query connection status...

for num  in {0..2}
do
    echo -e "AT\r\n" >> $ATDEV; echo -e "AT^NDISSTATQRY?\r\n" >> $ATDEV ; cat $ATDEV > /tmp/huawei

    res=`cat /tmp/huawei | grep '\^NDISSTATQRY:' | awk '{print $2}' | awk -F[','] '{print $1}'`
    if [ "$res" == "1" ];then
        echo "0"   >   $dialnum
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


    # echo -e "AT\r\n" > $ATDEV; echo -e "AT^NDISSTATQRY?\r\n" > $ATDEV
    # while read lines
    # do
    #     if [[ "$lines" == *"^NDISSTATQRY:"* ]]; then
    #         res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $1}')
    #         if [ "$res" == "1" ];then
    #             echo Net status is online...
    #             exit 0
    #         elif [ "$res" == "0" ];then
    #             break
    #         else
    #             echo Retrt query connection status.
    #             exit -1
    #         fi
    #     fi
    # done < $ATDEV

#--------------------------------------------
# Query the Connection Status Done
#--------------------------------------------

echo -e "AT^NDISDUP=1,0\r\n" >> $ATDEV

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
echo -e "AT\r\n" >> $ATDEV ; echo -e "AT+CGREG?\r\n" >> $ATDEV ; cat $ATDEV > /tmp/huawei
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

echo -e "AT^SYSINFOEX\r\n" >> $ATDEV
cat $ATDEV >> /tmp/huawei

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

echo -e "AT\r\n" >> $ATDEV
echo -e "AT^NDISDUP=1,1\r\n" >> $ATDEV

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

# udhcpc -R -n -A 15 -i usb0
udhcpc -n -i usb0


# Get cloud ip address
if [ "$(route -n | grep $cloudaddr)" == "" ];then
    # echo Cloud IP Address = $cloudaddr >> $logfile
    route add -net $cloudaddr netmask 255.255.255.255 dev usb0
fi

echo 4G Status [Online ]: `date '+%Y-%m-%d %H:%M:%S'` >> $logfile

echo -e "AT^LEDCTRL=1\r\n" >> $ATDEV

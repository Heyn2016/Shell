#!/bin/sh
#--------------------------------------------
# Platform: ARM Linux
# Author:   Heyn
#
# History:  2017/02/22 V1.0.1[Heyn]
#           2017/03/17 V1.1.0[Heyn] New add AT commands
#           2017/03/20 V1.1.1[heyn] Offline 4G & Get cloud ip address method
#           2017/03/21 V1.1.2[heyn] Bug fix[Removed HUAWEI module cloudaddr is NULL]
#           2017/03/22 V1.2.0[heyn] Changed ttyUSB0 to ttyUSB2 & check ttyUSB0 lock status
#           2017/04/05 V1.2.1[heyn] Bug fix
#
#--------------------------------------------

#--------------------------------------------
# User config start
#--------------------------------------------

webpath=/www/pages/htdocs/conf/Pbox.xml
timesyncpath=/etc/systemd/timesyncd.conf
confpath=/tmp/pboxConfig

ltemodulename="usb0"
netmode="gateway"
cloudaddr="47.93.79.77"

#--------------------------------------------
# Setting default value
#--------------------------------------------

echo "netmode="$netmode      >   $confpath
echo "cloudaddr="$cloudaddr >>   $confpath

echo "[Time]"           > $timesyncpath
echo "NTP=$cloudaddr"  >> $timesyncpath

if [ ! -f "$webpath" ]; then
    echo $webpath file is not exist.
    exit 0
fi

#--------------------------------------------
# Get network mode & Get cloud ip address
#--------------------------------------------

while read lines
do
    item=`echo $lines | awk -F['>'] '/\<Mode\>/{print $2}' | awk -F['<'] '{print $1}'`
    if [ "$item" == "4G" ];then
        netmode=$item
    elif [ "$item" == "gateway" ];then
        netmode=$item
    fi
    # New 2017-03-20 [Get cloud ip address]
    item=`echo $lines | awk -F['>'] '/\<CloudInfo\>/{print $3}' | awk -F['<'] '{print $1}'`
    if [ -n "$item" ];then
        cloudaddr=$item
    fi
done<$webpath

#--------------------------------------------
# 2017/04/05 V1.2.1 Bug fix [New add]
#--------------------------------------------
echo "netmode="$netmode      >   $confpath
echo "cloudaddr="$cloudaddr >>   $confpath

echo "[Time]"    > $timesyncpath
echo "NTP=$cloudaddr" >> $timesyncpath

#--------------------------------------------
# Check LTE module
#--------------------------------------------
vidpid=$(lsusb | grep 'Huawei' | awk '{print $6}' | awk -F[':'] '{print $1 $2}')
if [ "$vidpid" != "12d115c1" ];then
    echo HUAWEI ME909s-821 Module not detected.
    echo `systemctl stop cora.timer`
    exit 0
fi


for num  in 0 1 2 3 4
do
    if [ ! -c "/dev/ttyUSB$num" ]; then
        echo HUAWEI LTE Module [$num] is not exist.
        echo `systemctl stop cora.timer`
        exit 0
    fi
done

# Debug Mode
# netmode="gateway"

#--------------------------------------------
# 2017/04/05 V1.2.1 Bug fix [Delete]
#--------------------------------------------
# echo "netmode="$netmode     >   $confpath
# echo "cloudaddr="$cloudaddr >>  $confpath

# echo "[Time]"    > $timesyncpath
# echo "NTP=$cloudaddr" >> $timesyncpath

#--------------------------------------------
# New : 2017/03/22
#--------------------------------------------
# lockUSB0="/var/lock/LCK..ttyUSB0"
# if [ -f "$lockUSB0" ]; then
#     rm /var/lock/LCK..ttyUSB0
#     echo "rm /var/lock/LCK..ttyUSB0"
# fi


#--------------------------------------------
# HUAWEI ME909S
# New : 2017/03/17
#--------------------------------------------

sleep 1s
ATDEV=/dev/ttyUSB2

echo -e "AT\r\n"        >> $ATDEV

echo -e "ATE0\r\n"      >> $ATDEV      # Close ECHO
echo -e "AT^CURC=0\r\n" >> $ATDEV      # Close part of the initiative to report, such as signal strength of the report
echo -e "AT^STSF=0\r\n" >> $ATDEV      # Close the STK's active reporting
echo -e "ATS0=0\r\n"    >> $ATDEV      # Turn off auto answer
echo -e "AT+CGREG=2\r\n" >> $ATDEV     # Open the PS domain registration status changes when the active reporting function
echo -e "AT+CMEE=2\r\n" >> $ATDEV      # When the error occurs, the details are displayed

if [ "$netmode" == "4G" ];then
    echo -e "AT^LEDCTRL=1\r\n" >> $ATDEV
else
    echo -e "AT^LEDCTRL=0\r\n" >> $ATDEV
fi

# sleep 1s
echo -e "AT^NDISDUP=1,0\r\n" >> $ATDEV
stty -F $ATDEV raw speed 9600 min 0 time 10

echo "netmode="$netmode      >   $confpath
echo "cloudaddr="$cloudaddr >>   $confpath


echo "0"                     >   /tmp/dialnum

echo configure.service finished...

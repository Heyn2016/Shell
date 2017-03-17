#!/bin/sh
#--------------------------------------------
# Platform: ARM Linux
# Author:   Heyn
#
# History:  2017/02/22 V1.0.1[Heyn]
#           2017/03/17 V1.1.0[Heyn] New add AT commands
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

# Debug Mode
# netmode="gateway"

echo "netmode="$netmode     >   $confpath
echo "cloudaddr="$cloudaddr >>  $confpath

timesyncpath=/etc/systemd/timesyncd.conf
echo "[Time]"    > $timesyncpath
echo "NTP=$cloudaddr" >> $timesyncpath

#--------------------------------------------
# HUAWEI ME909S
# New : 2017/03/17
#--------------------------------------------

sleep 2s
while read lines
do
    if [ "$lines" == "OK" ];then
        break
    fi
    echo -e "AT\r\n"        > /dev/ttyUSB0
done < /dev/ttyUSB0


echo -e "ATE0\r\n"      > /dev/ttyUSB0      # Close ECHO
echo -e "AT^CURC=0\r\n" > /dev/ttyUSB0      # Close part of the initiative to report, such as signal strength of the report
echo -e "AT^STSF=0\r\n" > /dev/ttyUSB0      # Close the STK's active reporting
echo -e "ATS0=0\r\n"    > /dev/ttyUSB0      # Turn off auto answer
echo -e "AT+CGREG=2\r\n" > /dev/ttyUSB0     # Open the PS domain registration status changes when the active reporting function
echo -e "AT+CMEE=2\r\n" > /dev/ttyUSB0      # When the error occurs, the details are displayed

if [ "$netmode" == "4G" ];then
    echo -e "AT\r\n"        > /dev/ttyUSB0
    echo -e "AT^LEDCTRL=1\r\n" > /dev/ttyUSB0
    echo LEDCTRL ON.
else
    echo -e "AT\r\n"        > /dev/ttyUSB0
    echo -e "AT^LEDCTRL=0\r\n" > /dev/ttyUSB0
    echo LEDCTRL OFF.
fi


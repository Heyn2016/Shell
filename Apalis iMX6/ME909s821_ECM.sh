#!/bin/sh
#--------------------------------------------
# Platform: ARM Linux
# Author:   Heyn
#
# History:  2017/02/22 V1.0.1[Heyn]
#
# /etc/systemd/system/network-lte.service
#
# [Unit]
# Description=HUAWEI ME909s-821
# After=multi-user.target
# [Service]
# Type=oneshot  #Similar to simple, but only once, Systemd will wait for it to finish before starting other services
# ExecStart=/etc/lte.sh
# [Install]
# WantedBy=multi-user.target
#
# <yours.service starts after network-lte.service>
#
# /etc/systemd/system/yours.service
# [Unit]
# Description=My Application for Python3.5.2
# After=multi-user.target network-lte.service
# [Service]
# Type=simple   #The ExecStart field starts the process as the main process
# ExecStart=/usr/bin/python /home/root/main.py &
# [Install]
# WantedBy=multi-user.target
#
#
# <Linux's command for start services>
#systemctl enable network-lte.service
#systemctl enable yours.service
#
#--------------------------------------------

#--------------------------------------------
# User config start
#--------------------------------------------

webpath=/www/pages/htdocs/conf/AnyLink.xml
ltemodulename="usb0"
logfile=/tmp/lte.log

echo "network-lte.service start" > $logfile

#--------------------------------------------
# User config end
#--------------------------------------------

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

# Debug
netmode="4G"

if [ "$netmode" == "gateway" ];then
    echo Wired connection... >> $logfile
    exit 0
fi

echo "Wireless connection" >> $logfile

#---------------------------------------------------------------
# Check PCIe LTE module
#---------------------------------------------------------------
# Bus 002 Device 003: ID 12d1:15c1 Huawei Technologies Co., Ltd.
#---------------------------------------------------------------

vidpid=$(lsusb | grep 'Huawei' | awk '{print $6}' | awk -F[':'] '{print $1 $2}')
if [ "$vidpid" != "12d115c1" ];then
    echo HUAWEI ME909s-821 Module not detected. >> $logfile
    exit 0
fi

#--------------------------------------------
# Check LTE module
#--------------------------------------------

for num  in 0 1 2 3 4
do
    if [ ! -c "/dev/ttyUSB$num" ]; then
        echo HUAWEI LTE Module is not exist. >> $logfile
        exit 0
    fi
done

#--------------------------------------------
# Start LED
#--------------------------------------------
echo -e "AT\r\n" > /dev/ttyUSB0
echo -e "AT^LEDCTRL=1\r\n" > /dev/ttyUSB0

#--------------------------------------------
# Detect SIM Card <Method 1st>
#--------------------------------------------

# echo -e "AT^ICCID?\r\n" > /dev/ttyUSB0
# while read lines
# do
#     if [[ "$lines" == *"ERROR"* ]];then
#         echo SIM card not detected. $lines
#         exit 0
#     elif [[ "$lines" == *"^ICCID:"* ]];then
#         echo $lines
#         break;
#     fi
# done < /dev/ttyUSB0

#--------------------------------------------
# Detect SIM Card <Method 2nd>
#--------------------------------------------

# echo -e "AT^SYSINFOEX\r\n" > /dev/ttyUSB0
# while read lines
# do
#     if [[ "$lines" == *"^SYSINFOEX:"* ]];then
#         # <srv_status>: indicates the system service status.
#         res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $1}')
#         if [ "$res" == "2" ];then
#             res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $4}')
#             # <sim_state>: indicates the state of the SIM card.
#             if [ "$res" == "1" ];then
#                 break
#             elif [ "$res" == "255" ];then
#                 echo SIM card not detected. $lines
#                 exit 0
#             fi
#         else
#             echo No services or Restricted services or Restricted regional services. $lines
#             exit 0
#         fi 
#     fi
# done < /dev/ttyUSB0

echo -e "AT^SYSINFOEX\r\n" > /dev/ttyUSB0
while read lines
do
    if [[ "$lines" == *"^SYSINFOEX:"* ]];then
        res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $4}')
        # <sim_state>: indicates the state of the SIM card.
        if [ "$res" == "1" ];then
            break
        elif [ "$res" == "255" ];then
            echo SIM card not detected. $lines >> $logfile
            exit 0
        fi
    else
        n=$(($n + 1))
        if [ "$n" -gt 100 ];then
            echo SIM card not detected and timeout. $lines >> $logfile
            exit 0
        fi
    fi
done < /dev/ttyUSB0

#--------------------------------------------
# Query the Connection Status
#--------------------------------------------

# echo -e "AT\r\n" > /dev/ttyUSB0
# echo -e "AT^NDISSTATQRY?\r\n" > /dev/ttyUSB0
# while read lines
# do
#     if [[ "$lines" == *"^NDISSTATQRY:"* ]];then
#         res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $1}')
#         if [ "$res" == "1" ];then
#             echo Close current network connection.
#             echo -e "AT\r\n" > /dev/ttyUSB0
#             echo -e "AT^NDISDUP=1,0\r\n" > /dev/ttyUSB0
#             sleep 5s
#             exit 0 
#         else
#             break
#         fi
#     fi
# done < /dev/ttyUSB0

#--------------------------------------------
# Start LTE Internet mode
#--------------------------------------------

echo Start LTE connection...
echo -e "AT\r\n" > /dev/ttyUSB0
echo -e "AT^NDISDUP=1,1\r\n" > /dev/ttyUSB0

while read lines
do
    if [[ "$lines" == *"ERROR"* ]];then
        echo Start LTE Internet mode is $lines >> $logfile
        exit 0
    elif [[ "$lines" == *"OK"* ]];then
        echo Start LTE Internet mode is $lines >> $logfile
        break;
    fi
done < /dev/ttyUSB0

#--------------------------------------------
# Query the Connection Status
#--------------------------------------------
# sleep 3s
# echo -e "AT\r\n" > /dev/ttyUSB0
# echo -e "AT^NDISSTATQRY?\r\n" > /dev/ttyUSB0
# while read lines
# do
#     if [[ "$lines" == *"^NDISSTATQRY:"* ]];then
#         res=$(echo $lines | awk '{print $2}' | awk -F[','] '{print $1}')
#         if [ "$res" == "1" ];then
#             echo Connected Done
#         else
#             echo Disconnected Done
#         fi
#     fi
# done < /dev/ttyUSB0

udhcpc -i $ltemodulename


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


echo ip:$ip,mask:$mask,broadcast:$broadcast,gateway:$gateway,dns:$dns >> $logfile

if [ "$ip" == "" ];then
    echo HUAWEI LTE Module dial failure >> $logfile
    exit 1
fi

# Get cloud ip address

cat $webpath |awk -F['>'] '/\<CloudInfo\>/{print $3}'|while read line

do
    cloudaddr=`echo $line | awk -F['<'] '{print $1}'`
    
    if [ "$(route -n | grep $cloudaddr)" == "" ];then
        echo Cloud IP Address = $cloudaddr >> $logfile
        route add -net $cloudaddr netmask 255.255.255.255 dev $ltemodulename
    fi
done



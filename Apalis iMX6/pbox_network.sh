#!/bin/bash
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

#/etc/systemd/network/wired.network

FILE="/etc/systemd/network/wired.network"

# return 0(success) is a valid net
# return 1(failure) is not a valid net
function valid_ip()
{
    local  ip=$1
    local  stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

if [ ! -f "$webpath" ]; then
    echo $webpath file is not exist.
    exit 0
fi

dhcpmod="NO"
network="192.168.5.266"
gateway="192.168.5.1"
netmask="255.255.255.0"
dns="8.8.8.8"

# <WAN dhcp="NO" mask="255.255.255.0" gateway="192.168.5.1" dns="8.8.8.8" ip="192.168.5.126"/>
while read lines
do
    items=`echo $lines | awk -F[' '] '/\<WAN/{print $0}'`
    if (("$echo ${#items}" > "0")); then
        dhcpmod=`echo $items | awk -F[' '] '/\<WAN/{print $2}'`
        network=`echo $items | awk -F[' '] '/\<WAN/{print $6}' | awk -F['\/'] '{print $1}' | awk -F['\"'] '/ip\=/{print $2}'`
        netmask=`echo $items | awk -F[' '] '/\<WAN/{print $3}' | awk -F['\"'] '/mask\=/{print $2}'`
        gateway=`echo $items | awk -F[' '] '/\<WAN/{print $4}' | awk -F['\"'] '/gateway\=/{print $2}'`
        dns=`echo $items | awk -F[' '] '/\<WAN/{print $5}' | awk -F['\"'] '/dns\=/{print $2}'`
    fi
done<$webpath


if ! valid_ip $network; then 
    printf "It isn't a valid ip address !!\n"
    exit 1
fi

# Writing DHCP Service File
if [[ $dhcpmod =~ "YES" ]];then
    printf "Pbox DHCP ON\n"
    echo "[Match]"     > $FILE
    echo "Name=eth0"  >> $FILE
    echo "" >> $FILE
    echo "[Network]"  >> $FILE
    echo "DHCP=ipv4"  >> $FILE
    exit 0
fi

# Writing Static Service File
echo "[Match]"    > $FILE
echo "Name=eth0" >> $FILE
echo "" >> $FILE

echo "[Network]"  >> $FILE

echo "Address=$network/24" >> $FILE
echo "Gateway=$gateway"    >> $FILE
echo "DNS=$dns"  >> $FILE

exit 0
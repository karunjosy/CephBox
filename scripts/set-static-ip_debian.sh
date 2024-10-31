#!/bin/bash

# This script can be used to set the static ip address for debian.
# If you are not familer with debian, this script will help you to set the static ip.

# Usage "bash set-static-ip_debian.sh"
# Tested version details:
#   - debian 12.7

# check whether the script runs as root user
if [ "$(id -u)" != "0" ]
then
  echo "This script must be run as root" 1>&2 exit 1
fi


# Declare clour variables
GREEN='\033[0;32m'
RED="\033[0;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
BLUE="\033[0;34m"
NOCOLOR="\033[0m"
BOLD="\033[1;33m"


# Print info and fetch the details from the user
echo -e "${GREEN} This script can be used to set the static ip address for debian..\n\n ${NOCOLOR}\n${CYAN}These are the available devices in this machine:${NOCOLOR}\n "
ip a || ifconfig

# Variables
echo -ne "${GREEN}Review the above result before choosing the device name and choose the network interface which you want to set the static IP(eg: "enp1s0"):${NOCOLOR} "
read INTERFACE
echo -ne "${GREEN}Enter the IP address:${NOCOLOR} "
read IP_ADDRESS
echo -ne "${GREEN}Enter the netmask:${NOCOLOR} "
read NETMASK
echo -ne "${GREEN}Enter the gateway:${NOCOLOR} "
read GATEWAY
echo -ne "${GREEN}Enter the DNS1:${NOCOLOR} "
read DNS1
DNS2="8.8.4.4"

# Confirmation
echo -ne "\n
${CYAN}-----------<Details>----------------${NOCOLOR}\n"
echo -ne "\n${GREEN}Interface detail: ${BLINKING}${RED}$INTERFACE ${NOCOLOR}"
echo -ne "\n${GREEN}IPAddress: ${BLINKING}${RED}$IP_ADDRESS ${NOCOLOR}"
echo -ne "\n${GREEN}Netmask: ${BLINKING}${RED}$NETMASK ${NOCOLOR}"
echo -ne "\n${GREEN}Gateway: ${BLINKING}${RED}$GATEWAY ${NOCOLOR}"
echo -ne "\n${GREEN}DNS infomation:\n  ${BLINKING}${RED}- DNS1: $DNS1 \n  - DNS2: $DNS2 ${NOCOLOR}"
echo -ne "\n${CYAN}----------------------------${NOCOLOR}\n"
echo -ne "${GREEN}Confirm whether the above details are correct(${BLINKING}${RED}yes/no${NOCOLOR}): "
read condition1

# Check the confirmation and proceed further
case $condition1 in
[yY][Ee][Ss] )
# Backup the current interfaces file
date_var=`date "+%Y-%m-%d-%T"`
cp /etc/network/interfaces /etc/network/interfaces.bak-${date_var}

# Configure the network interface

> /etc/network/interfaces
cat <<EOF >> /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo

# The primary network interface
iface lo inet loopback
auto $INTERFACE
iface $INTERFACE inet static
address $IP_ADDRESS
netmask $NETMASK
gateway $GATEWAY
dns-nameservers $DNS1 $DNS2
EOF

# Restart the networking service to apply changes
systemctl restart networking

# Display the new network configuration
echo -ne "\n${YELLOW}IP details:${NOCOLOR}\n"
echo -ne "\n${CYAN}----------------------------${NOCOLOR}\n"
ip addr show $INTERFACE
echo -ne "\n${CYAN}----------------------------${NOCOLOR}\n"
echo -ne "\n${GREEN}Taken the network configuration backup as - /etc/network/interfaces.bak-${date_var}\n"
echo -ne "\n${GREEN}If you need any additional configuration, feel free to modify using the config file - /etc/network/interfaces\n"
;;

*) echo "Invalid input"
            ;;
esac

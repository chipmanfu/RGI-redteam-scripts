#!/bin/bash
# Written by Chip McElvain 168COS
# Set redteam server back to defaults.

# Clears terminal for output messages
clear

# Set variable names to add color codes to menu displays.
white="\e[1;37m"
ltblue="\e[1;36m"
ltgray="\e[0;37m"
red="\e[1;31m"
green="\e[1;32m"
whiteonblue="\e[5;37;44m"
yellow="\e[1;33m"
default="\e[0m"

# Check to make sure they really want to do this.
echo -e "\n\t$ltblue This will revert the redirector back to defaults.\n"
read -p "         Are you sure you want to do this?(yes/no) " ans
case $ans in
  y|Y|yes|Yes|YES) 
    iptables -F
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -t nat -F
    # Gets the name of the interface
    intname=`ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}'`
    # deletes interface configuration and clears the routing table
	cp /etc/nginx/nginx.conf.org /etc/nginx/nginx.conf
	hostname rts
    ip addr flush $intname && ip route flush table main
    echo -e "auto lo\niface lo inet loopback\nauto $intname" > /etc/network/interfaces
    echo -e "iface $intname inet static" >> /etc/network/interfaces
    echo -e "	 address 1.1.1.100" >> /etc/network/interfaces
    service networking restart
    echo -e "\n\t $green The redirector has been revert back to orginal configuration\n";;
  *)
    echo -e "\n\t $ltgray Revert Aborted.. Script exiting$default\n" 
    exit 0;;  
esac
echo -e "$default"

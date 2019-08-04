#!/bin/bash
# Written by Chip McElvain 168COS
# Goes through the redteam-dns.lst and tests resolution.

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

# Set location to the config files
dnsconf="/root/dnsfile.txt"
rootIPfile="/root/scripts/rootips.txt"

# Check if DNS config file exists
if [ ! -s $dnsconf ]; then
  echo -e "\n\t\t\t$red ####  Error ####"
  echo -e "\t$white Your DNS records file ($ltblue $dnsconf $white) doesn't exist"
  echo -e "\t Either you haven't assigned DNS records yet, or this file has"
  echo -e "\t been moved or deleted.\n"
  exit 1
fi

# Check if root IP config file exists
if [ ! -s $rootIPfile ]; then
  echo -e "\n\t\t\t$red ####  Error ####"
  echo -e "\t$white The list of RGI root IP's is missing.  This file show be"
  echo -e "\t located at ($green $rootIPfile $white)"
  echo -e "\t This file should a list of all A-M root server IP's"
  echo -e "\t where each IP is on a new line.\n"
  exit 1
fi

# check domain resolution against all root servers.
echo -e "\n\t$ltgray The script is running an nslookup for all the domains listed in" 
echo -e "\t$green /root/dnsfile.txt$ltgray against all of the RGI root DNS servers"
echo -e "\t It's checking for the domain name and also that the IP matches what is"
echo -e "\t listed in $green /root/dnsfile.txt $ltgray"
echo -e "\n\t$yellow NOTE: $ltgray It will say which root server it is currently working on"
echo -e "\t and will only display errors, so if you don't see red everything resolved correctly\n"

#Loop through root servers
for i in `cat $rootIPfile`
do
  echo -e "\t$green Working on $i"
  # Loop through domains in /root/dnsfile.txt
  while read d
  do
    # ignores comments or blank lines in redteam-dns.lst
    if [[ $d == \#* ]] || [[ $d == "" ]]
    then continue
    fi 
    #seperate line in redteam-dns.lst into domain and IP variables.
    domain=`echo $d | cut -d, -f1`
    ip=`echo $d | cut -d, -f2`
    #Checks if nslookup resolves on the root server and returns an resolved
    #IP or nothing.
    resolveIP=$( nslookup $domain $i | awk -F':' '/^Address: / { matched = 1 } matched { print $2}' | xargs)
    #Checks is nslookup resolved an IP
    if [ -z $resolveIP ]
    then 
      echo -e "\t\t$red $domain lookup failed on root server $i"
    else 
      # Checks that the resolved IP matches the redteam-dns.lst IP
      if [ $resolveIP != $ip ]
      then
        echo -e "\t\t$red $domain shows $resolveIP and not $ip on root server $i"
      fi
    fi
  done<$dnsconf
done

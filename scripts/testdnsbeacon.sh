#!/bin/bash
# Written by Chip McElvain 168COS
# Script will run through your DNS config file and test CobaltStrike DNS beacons.
# It will generate a randomnum and prepend it to the domain and do a NSLOOKUP
# then check for a recursive response that should come from your cobaltstike teamserver
# It it gets a response it will also show what the defualt Cobaltstrike DNS IP is set to.

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

# Set location to the config file
dnsconf="/root/dnsfile.txt"

if [ ! -s $dnsconf ]; then
  echo -e "\n\t\t\t$red ####  Error  ####"
  echo -e "\t$white Your DNS records file ($ltblue/root/dnsfile.txt$white) doesn't exist"
  echo -e "\t Either you haven't assigned DNS records yet, or this file has"
  echo -e "\t been moved or deleted. Script exiting\n"
  exit 1
fi
echo -e "\n\tThis script tests Cobalt Strike DNS beacons."
echo -e "\tMake sure your cobalt strike server is running, and your DNS listener is running"
echo -ne "\n\tPlease press enter to continue."
read ans
# Clears terminal for output message
clear
echo "RESULTS BELOW"
while read p
do
  # ignore comments or blank lines
  if [[ $p == \#* ]] || [[ $p == "" ]]; then continue; fi
  # generate random number for subdomain
  randnum=`shuf -i 10000-99999 -n 1`
  domain=`echo $p | cut -d, -f1`
  resolvedIP=`nslookup $randnum.$domain 17.72.153.88 | awk '/Non-auth/{nr[NR+2]}; NR in nr' | awk '{print$2}'`
  if [[ $resolvedIP != "" ]]; then
    echo -e "$white $domain: $green GOOD $white - resolved IP is $green $resolvedIP"
  else
    echo -e "$white $domain: $red BAD"
  fi
done<$dnsconf

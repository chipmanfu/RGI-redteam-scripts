#!/bin/bash
# Written by Chip McElvain 168COS
# This creates an initial lookup of your newly added DNS records and 
# places it in the recursive DNS servers cache.  This helps prepare
# Cobalt Strike DNS beacons for use.  After you run this
# run testdnsbeacon.sh to validate your Cobalt Strike DNS set up is functional.
# it will add a beacon in your CS window, just remove them afterward.

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

# Check if DNS config file exists
if [ ! -s $dnsconf ]; then
  echo -e "\n\t\t\t$red ####  Error  ####"
  echo -e "\t$white Your DNS records file ($ltblue/root/dnsfile.txt$white) doesn't exist"
  echo -e "\t Either you haven't assigned DNS records yet, or this file has"
  echo -e "\t been moved or deleted.\n"
  exit 1
fi

echo -e "\t$ltblue This will perform an initial nslookup of your newly added DNS records."
echo -e "\t This will ensure the domains are added to the recursive DNS servers cache."
echo -e "\t This seems to help solve some Cobalt Strike DNS beacon issues."
echo -e "\t $yellow NOTE: $ltgray Running this will add a beacon in your CS window,"
echo -e "\t just remove them after running this script."

# loop through dnsfile and perform an NSlookup for each domain against the RGI recursive DNS server.
while read p
do
  if [[ $p == \#* ]] || [[ $p == "" ]]; then continue; fi 
  domain=`echo $p | cut -d, -f1`
  nslookup $domain 17.72.153.88
done<$dnsconf

#!/bin/bash
# Written by Chip McElvain 168COS
# Manages RGI Domain name registration
# NOTE: you need to set up ssh keys between the a.root(198.41.0.4) and this redirector 
# before this will work.

# Set variable names to add color codes to menu displays.
white="\e[1;37m"
ltblue="\e[1;36m"
ltgray="\e[0;37m"
red="\e[1;31m"
green="\e[1;32m"
whiteonblue="\e[5;37;44m"
yellow="\e[1;33m"
default="\e[0m"

# Check for network connectivity to the RGI A.root server.
ping -c 1 198.41.0.4 1>/dev/null
if [[ $? -ne 0 ]]
then
  clear
  echo -e "\n\t\t\t$red ####  ERRROR  ####"
  echo -e "\t$ltgray The A.root server (198.41.0.4) can't be reached!!"
  echo -e "\t Check your network bridge and redirector IPs\n$default"
  exit 0;
fi

# get hostname, the hostname is used to tag DNS records on the RGI.  This allows them to be
# specifically removed later.  All domain zone files created on the RGI by this script
# will have a comment formatted like  ";REDTEAMZONE-hostname"
# additionally zone file references are added to named.conf and are tagged between the
# following comment list "//REDTEAMSTART-hostname" and "//REDTEAMEND-hostname" 
hostin=`hostname`

# set conf file location
DNSconf="/root/scripts/redteamDNS.txt"

# Set variables
random=0
bannertitle="DNS Management Menu"
# Header for all menu items, clears the terminal, adds a banner.
MenuBanner()
{
  clear
  printf "\n\t$ltblue %-60s %8s\n"  "$bannertitle" "<b>-Back"
  printf "\t$ltblue %60s %8s\n"  "" "<q>-Quit"
}

FormatOptions()
{
  local count="$1"
  local title="$2"
  local dnsname="$3"
  printf "\t$ltblue%3b )$white %-15b $green%-40b\n" "$count" "$title" "$dnsname"
}

DNSMenu()
{
  MenuBanner
  echo -e "\n\t$ltblue What would you like to do?"
  FormatOptions 1 "Add DNS records"
  FormatOptions 2 "Delete DNS records"
  echo -ne "\n\t$ltblue Enter a Selection: $white"
  read answer 
  case $answer in 
    1)  AddDNSMenu;;
    2)  DeleteDNSMenu;;
    b|B) DNSMenu;;
    q|Q) echo -e "$default"; exit 0;;
    *) echo -e "\n\t\t$red Invalid Selection, Please try again"; sleep 2
       DNSMenu;;
  esac
}

DeleteDNSMenu()
{
  MenuBanner
  echo -e "\n\t$yellow Note: DNS records are tagged with your Hostname.  Selecting"
  echo -e "\t option 2 will delete ones you previously created using this servers current"
  echo -e "\t hostname, but if another redteam server created records using this same "
  echo -e "\t hostname, they will get delete too\n"
  echo -e "\t$ltblue Which DNS records would you like to delete?"
  FormatOptions 1 "${red}All$white Redteam DNS Records"
  FormatOptions 2 "DNS records tagged for $yellow$hostin"
  echo -en "\n\t$ltblue Enter a Selection: $white"
  read answer
  case $answer in 
    1) delopt=1; DeleteDNS;;
    2) delopt=2; DeleteDNS;;
    b|B) DNSMenu;;
    q|Q) echo -e "$default"; exit 0;;
    *) echo -e "\n\t\t$red Invalid Selection, Please try again"; sleep 2
       DeleteDNSMenu;;
  esac
}

DeleteDNS()
{
  MenuBanner
  if [[ $delopt == 1 ]]; then
    echo -e "\n\t$yellow Warning!!! This will delete$red ALL$yellow Red Team DNS records.\n"
    echo -e "\t$ltblue Are you absolutely sure this is what you want to do?"
  elif [[ $delopt == 2 ]]; then
    echo -e "\n\t$yellow Warning! Again if any other red team systems also set DNS records using"
    echo -e "\t the hostname $hostin, this action will delete DNS records"
    echo -e "\t	for those systems as well"
    echo -e "\n\t$ltblue Are you sure you want to delete all$yellow $hostin$ltblue Red Team DNS records?"  
  else  
    echo -e "\n\t$red Script error, script exiting, not even sure how you made this happen."
    echo -e "$default"; exit 0;
  fi
  echo -en "\t$ltblue Enter y to continue "
  read answer 
  case $answer in
     y|Y|yes|YES|Yes) 
       clear
       echo -e "\n\t$ltblue Deleting DNS records in 10 seconds, hit ctrl+C to abort"
       sleep 10
       if [[ $delopt == 1 ]]; then
         ssh 198.41.0.4 '/root/scripts/delete-REDTEAM-DNS.sh'
         echo -e "\n\t$green All Red Team DNS has been deleted, I hope you really wanted to do this."
       elif [[ $delopt == 2 ]]; then
         ssh 198.41.0.4 "/root/scripts/delete-REDTEAM-DNS.sh $hostin"
         echo -e "\n\t$green All Red Team DNS tagged with $hostin have been deleted," 
         echo -e "\t I hope you really wanted to do this."
       fi;;
     b|B) DeleteDNSMenu;;
     q|Q) echo -e "$default"; exit 0;;
     *) echo -e "\n\t\t$red Invalid Selection, Please try again"; sleep 2
        DeleteDNS;;
   esac
   
}
  
AddDNSMenu()
{
  MenuBanner
  echo -e "\n\t$ltblue How would you like to assign domain names?"
  FormatOptions 1 "Manually create domain name/s."
  FormatOptions 2 "Use randomly generated one/s."
  echo -ne "\n\t$ltblue Enter a Selection: $white"
  read answer
  case $answer in
    1)  ManualDNS;;
    2)  random=1; ExecAndValidate;;
    b|B) DNSMenu;;
    q|Q) echo -e "$default"; exit 0;;
    *) echo -e "\n\t\t$red Invalid Selection, Please try again"; sleep 2
       AddDNSMenu;;
  esac
}

ManualDNS()
{
  MenuBanner
  intname=`ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}'`
  iplist=`ip a | grep $intname | grep inet | awk '{print $2}' | cut -d/ -f1`
  numip=`echo "$iplist" | wc -l`
  if [[ $numip == 1 ]]; then
    echo -e "\n\t$ltblue Your Current IP is $green $iplist"
    echo -e "\n\t$ltblue Please set the Fully Qualified Domain Name you would like to use"
    echo -ne "\n\t$ltblue Here:"
    read DNSin
    regexfqn="(?=^.{4,253}$)(^(?:[a-zA-Z](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z])?\.)+[a-zA-Z]{2,}$)"
    if [[ `echo $DNSin | grep -P $regexfqn` ]]; then
      #Remove any previously set FQDN for the IP selected.
      sed -i "/$iplist/d" $DNSconf
      #Add new FQDN
      lowercaseDNS=`echo $DNSin | tr '[:upper:]' '[:lower:]'`
      echo "$lowercaseDNS,$iplist" >> $DNSconf
      ExecAndValidate
    else
      echo "$DNSin is not a valid FQDN, please try again."; sleep 2
      ManualDNS
    fi
  else  
    echo -e "\n\t$ltblue You currently have multiple IP's, you can set manual FQDNs"
    echo -e "\t$ltblue for each one, select an IP from the list to set a FQDN for that"
    echo -e "\t$ltblue IP, once set it will bring you back to this menu, select D for"
    echo -e "\t$ltblue done when you're finished adding FQDN's to IPs\n"
    count=1
    for ip in $iplist 
    do
      dnsadded=`grep $ip $DNSconf 2>/dev/null | cut -d, -f1`	
      if [[ ! -z $dnsadded ]]; then
        FormatOptions "$count" "$ip" "$dnsadded"
      else
        FormatOptions "$count" "$ip"
      fi
      let count++
    done
    FormatOptions "c" "Clear all"
    FormatOptions "d" "Done"
    echo -ne "\n\t$ltblue Enter a Selection Here: $white"
    read answer
    case $answer in
      b|B) DNSMenu;;
      q|Q) echo -e "$default"; exit 0;;
      c|C) cp /dev/null $DNSconf; ManualDNS;; 
      d|D) ExecAndValidate;;
      *) if [[ $answer -ge 1 ]] && [[ $answer -le $numip ]]; then
           IPselected=`echo "$iplist" | sed -n ${answer}p`
           DNSentry
         else 
           echo -e "\n\t\t$red Invalid Selection, Please try again"; sleep 2
           ManualDNS
         fi;;
    esac
  fi
}

DNSentry()
{
  MenuBanner
  domainin=`grep $IPselected $DNSconf 2>/dev/null | cut -d, -f1`	
  if [[ $domainin != "" ]]; then
    echo -e "\n\t$ltblue DNS already assigned as $green $domainin"
    echo -e "\t$ltblue This will replace it, if this isn't what you want hit B to go back"
  fi
  echo -e "\n\t$ltblue Your Current IP is $green $IPselected"
  echo -e "\n\t$ltblue Please set the Fully Qualified Domain Name you would like to use"
  echo -ne "\n\t$ltblue Here:$white "
  read DNSin
  if [[ $DNSin == b ]] || [[ $DNSin == B ]]; then ManualDNS; fi
  if [[ $DNSin == q ]] || [[ $DNSin == Q ]]; then exit 0; fi
  regexfqn="(?=^.{4,253}$)(^(?:[a-zA-Z](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z])?\.)+[a-zA-Z]{2,}$)"
  if [[ `echo $DNSin | grep -P $regexfqn` ]]; then
    #Remove any previously set FQDN for the IP selected.
    sed -i "/$IPselected/d" $DNSconf
    #Add new FQDN
    lowercaseDNS=`echo $DNSin | tr '[:upper:]' '[:lower:]'`
    echo "$lowercaseDNS,$IPselected" >> $DNSconf
    ManualDNS
  else
    echo -e "\t\t$red $DNSin is not a valid FQDN, please try again."; sleep 2
    DNSentry
  fi
}

ExecAndValidate()
{
  clear
  if [[ $random == 1 ]]; then 
    echo -e "\n\t$ltblue This will assign new random domains to this redirectors IP's."
    echo -e "\t If you already ran this, you will still have the old domains assigned as well as a new list"
    echo -e "\t However this will overright your existing list at /root/dnsfile.txt"
    echo -e "\t If this is what you want to do, you should make a copy of the"
    echo -e "\t current /root/dnsfile.txt before running this."
    echo -e "\t If this is the first time, then no worries\n"
    read -p "       Are you sure you want to continue <y or n>: " ans
    case $ans in
      y|Y|yes|YES|Yes) ;;
      n|N|no|NO|No) DNSMenu; exit;;
      q|Q) echo -e "$default"; exit 0;;
      b|B) DNSMenu; exit;;
      *) echo "Invalid input, script exiting"; exit 0;;
    esac
    scp /root/scripts/IPList.txt 198.41.0.4:/root/scripts/autoredirector/iplist.txt
    ssh 198.41.0.4 '/root/scripts/autoredirector/makednsfile.sh /root/scripts/autoredirector/iplist.txt'
    ssh 198.41.0.4 '/root/scripts/add-REDTEAM-DNS.sh /root/scripts/autoredirector/dnsfile.txt'
    scp 198.41.0.4:/root/scripts/autoredirector/dnsfile.txt /root/dnsfile.txt
    ssh 198.41.0.4 'rm /root/scripts/autoredirector/dnsfile.txt'
    echo -e "$green  DNS Records assigned to the redirector IPs."  
    echo -e "$green  See /root/dnsfile.txt for a list of your domains.$default\n\n"
  else
    if [ ! -s $DNSconf ]
    then
      echo -e "\n\t$yellow No manually created DNS records found, script is exiting$default\n" 
      exit 0;
    fi
    # Tag the DNS file with the servers hostname
    hostin=`hostname`
    echo "# Hostname:$hostin" >> $DNSconf
    scp $DNSconf 198.41.0.4:/root/scripts/redteam-dns.lst
    mv $DNSconf /root/dnsfile.txt
    echo -e "$ltblue"
    ssh 198.41.0.4 '/root/scripts/add-REDTEAM-DNS.sh /root/scripts/redteam-dns.lst'
    echo -e "  DNS Records assigned to the redirector IPs."  
    echo -e "  See /root/dnsfile.txt for a list of your domains.$default\n\n"
  fi
}
DNSMenu

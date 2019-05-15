#!/bin/bash
# Written by Chip McElvain, 168COS
# Red Team infastructure multi-use set up script.  Uses backbone router information for IP configs
# stored in /root/backbonerouters to generate random IP's or set static IPs
# Uses: Cobalt Strike Teamserver, Apache HTTP/HTTPS payload server, NGINX redirector, 
# Phishing attackers using Mutt/Postfix

# set path variables
rtrpath="/root/backbonerouters"
cspath="/root/cobaltstrike"
csc2path="/root/cobaltstrike/Malleable-C2-Profiles-master"
# Set variable names to add color codes to menu displays.
bclr="\e[1;36m"
optclr="\e[1;36m"
valclr="\e[1;37m"
infoclr="\e[1;36m"
entclr="\e[0;37m"
iclr="\e[1;36m"
eclr="\e[1;31m"
h1clr="\e[1;33m"
h2clr="\e[5;37;44m"
h3clr="\e[1;32m"

# The following is the logic flow of the functions
#  -> MainMenu 
#     -> Option 1 Set up the Redirector
#	  -> SetUniqueHostname
#	  -> CountryMenu
#         -> CityMenu
#	  -> NumIPsMenu
#	  -> PortMenu
#		-> CustomInfo
#	  -> AttackerMenu
#	  -> ExecAndvalidate
#     -> Option 2 Set up Cobalt Strike Team server
#         -> CountryMenu
#         -> CityMenu
#	  -> IPoption
#     -> Option 3 Set up payload host
#	  -> CountryMenu
#	  -> CityMenu
#	  -> IPoption
#     -> Option 4 Change redirector IPs
#	  -> CountryMenu
#	  -> CityMenu
#	  -> NumIPsMenu
#	  -> ExecAndValidate
#     -> Option 5 Change redirector destination IP
#         -> PortMenu
#		-> CustomInfo
#   	  -> AttackerMenu
#         -> ExecAndValdiate
		
# Header for all menu items, clears the terminal, adds a banner.
MenuBanner()
{
  clear
  echo -e "\n\t$bclr  RED TEAM Infastructure BUILD SCRIPT\t\t\t$optclr <b>-Back"
  echo -e "\t\t\t\t\t\t\t$optclr <q>-Quit"
}

MainMenu()
{
  # Set initial variables, Resets values if user navigates back to the beginning
  setips=0
  setattackip=0
  setcsts=0
  setpayloadhost=0
  staticip=0
  randomip=0
  # Calls menu Banner
  MenuBanner
  # List options, get user input, process the input.
  echo -e "\n\t$optclr    1 )$valclr Set up a redirector"
  echo -e "\t$optclr    2 )$valclr Set up a Cobalt Strike teamserver"
  echo -e "\t$optclr    3 )$valclr Set up a payload host server"
  echo -e "\t$optclr    4 )$valclr Change redirector IPs"
  echo -e "\t$optclr    5 )$valclr Change redirector destination IP $iclr\n"
  read -p "       Enter a Option: " optin
  case $optin in
    1) opt=1; setips=1; setattackip=1; SetHostname;;
    2) opt=2; setips=1; setcsts=1; CountryMenu;;
    3) opt=3; setips=1; setpayloadhost=1; CountryMenu;;
    4) opt=4; setips=1; SetHostname;;
    5) opt=5; setattackip=1; PortMenu;;
    b|B) MainMenu;;
    q|Q) exit 0;;
    *) echo -e "\n\t\t$eclr Invalid Selection, Please try again"; sleep 2
       MainMenu;;
  esac
}

SetHostname()
{
  MenuBanner
  echo -e "\n\t$infoclr Set a hostname."
  echo -e "\t$valclr This will be used to identify DNS records related to this redirector."
  echo -e "\t$valclr If you've already changed the host name just press enter to continue$iclr\n"
  read -p "       Enter a unique hostname here: " hostin
  case $hostin in
    q|Q)  exit 0;;
    b|B)  MainMenu;;
      *)  if [[ $hostin == "" ]]; then
	         CountryMenu
		   elif ! [[ $hostin =~ [^a-zA-Z0-9] ]]; then
             hostname $hostin
             CountryMenu
           else
             echo -e "\n\t\t$eclr Invalid Selection, alphanumeric only. Please try again"; sleep 2
             SetHostname
           fi;;
  esac 
}

CountryMenu()
{
  MenuBanner
  # Sets initial variables, resets values if user navigates back.
  count=1
  # List options, get user input, process the input
  echo -e "\t$infoclr Select a Country of Origin$optclr"
  for folder in `ls $rtrpath`; do
    printf "\t$optclr%3d )$valclr %-23s\n" $count $folder 
    let "count++";
  done
  echo -e "$iclr"
  read -p "        Please Enter Selection Here: " country
  case $country in
    q|Q) exit 0;;
    b|B) MainMenu;;
      *) if (( $country >= 1 && $country < $count )) 2>/dev/null; then
            countrysel=`ls $rtrpath  | sed -n ${country}p`
            CityMenu
          else
            echo -e "\n\t\t$eclr Invalid Selection, Please try again"; sleep 2
            CountryMenu
          fi;;
  esac
}

CityMenu()
{
  MenuBanner
  # sets initial variables, resets values if user navigates back
  count=1
  # Get and display user selected items
  printf "\t\t$entclr%16s: $h1clr%-20s\n " "Country Selected" $countrysel
  # List options, get user input, process the input
  echo -e "\n\t$infoclr Select a City$optclr"
  for file in `ls $rtrpath/$countrysel | sed -e 's/\.txt//'`; do
    printf "\t$optclr%3d )$valclr %-23s\n" $count $file
    let "count++";
  done
  echo -e "$iclr"
  read -p "        Please Enter City Here: " city
  case $city in
    q|Q) exit 0;;
    b|B) CountryMenu;;
      *) if (( $city >= 1 && $city < $count )) 2>/dev/null; then
            routerfile=`ls $rtrpath/$countrysel | sed -n ${city}p`
            citysel=`echo $routerfile | sed -e 's/\.txt//'`
            if [[ $opt == 1 ]] || [[ $opt == 4 ]]; then
              NumIPsMenu
            else
              SetIPOption
            fi
          else
            echo -e "\n\t\t$eclr Invalid Selection, Please try again"; sleep 2
            CityMenu
          fi;;
   esac
}

NumIPsMenu()
{
  MenuBanner
  # Get and display user selected items  
  printf "\t\t$entclr%16s: $h1clr%-20s\n" "Country Selected" $countrysel
  printf "\t\t$entclr%16s: $h1clr%-20s\n" "City Selected" $citysel
  # List options, get user input, process the input 
  echo -e "\n\t$infoclr Select number of IPs you want to set."
  echo -e "$iclr"
  read -p "        Enter the number of IPs: " totalips
  case $totalips in
    q|Q) exit 0;;
    b|B) CityMenu;;
      *) if (( $totalips >= 1 && $totalips <= 200 )) 2>/dev/null; then
            totalipssel=$totalips
            if [[ $opt == 4 ]]; then 
              ExecAndValidate 
	        else 
              PortMenu 
	        fi
         else
           echo -e "\n\t\t$eclr Invalid Selection, the Max is set a 200 IPs"; sleep 2
           NumIPsMenu
         fi;;
  esac
}

SetIPOption()
{
  MenuBanner
  # List options, get user input, process the input.
  if [[ $opt == 2 ]]; then
    echo -e "\n\t$optclr Set the IP for your Cobalt Strike TeamServer."
  else
    echo -e "\n\t$optclr Set the IP for your payload Server."
  fi
  echo -e "\n\t$optclr    1)$valclr Set a static IP"
  echo -e "\t$optclr    2)$valclr Set a Random IP $iclr\n"
  read -p "       Enter a Selection: " optin
  case $optin in
    1) staticip=1; totalipssel=1; SetStaticIP;;
    2) randomip=1; totalipssel=1; 
         if [[ $setcsts == 1 ]]; then
           C2TypeMenu
         else
           ExecAndValidate
         fi;;
    b|B) CityMenu;;
    q|Q) exit 0;;
    *) echo -e "\n\t\t$eclr Invalid Selection, Please try again"; sleep 2
       SetIPOption;;
  esac
}

SetStaticIP()
{
  MenuBanner
  if [[ $opt == 2 ]]; then
    echo -e "\n\t$optclr Set your static IP for your Cobalt Strike TeamServer."
  else
    echo -e "\n\t$optclr Set your static IP for your payload Server."
  fi
  echo -e "\t$optclr enter [s] to see ip ranges for the country/city selected. $iclr\n"
  read -p "       Enter Static IP Here: " sIPin
  case $sIPin in
    q|Q)  exit 0;;
    b|B)  SetIPOption;;
    s|S)  showSubnets;;
      *) CheckIP $sIPin
         if [[ $? -eq 0 ]]; then
           IFS=. read IPoct1 IPoct2 IPoct3 IPoct4 <<< "$sIPin"
           for x in `cat $rtrpath/$countrysel/$citysel.txt`; do
             if [[ $x == \#* ]]; then continue; fi
             gateway=`echo $x | cut -d, -f1`
             subnet=`echo $gateway | cut -d/ -f2`
             min=`echo $gateway | cut -d/ -f1`
             max=`echo $x | cut -d, -f2`
             IFS=. read startoct1 startoct2 startoct3 startoct4 <<< "$min"
             IFS=. read endoct1 endoct2 endoct3 endoct4 <<< "$max"
             if [ $IPoct1 -ge $startoct1 ] && [ $IPoct1 -le $endoct1 ]; then
               if [ $IPoct2 -ge $startoct2 ] && [ $IPoct2 -le $endoct2 ]; then
                 if [ $IPoct3 -ge $startoct3 ] && [ $IPoct3 -le $endoct3 ]; then
                   if [ $IPoct4 -gt $startoct4 ] && [ $IPoct4 -le $endoct4 ]; then
                     staticgatewayin=$min
                     staticIPin=$sIPin/$subnet
                     staticIPsel=$sIPin
                     echo "valid IP : $staticIPin will use $staticgatewayin"
 	             found="yes"
                     break;
                   fi
		 fi
               fi
             fi 
           done
           if [[ $found == "yes" ]]; then
             if [[ $setcsts == 1 ]]; then
               C2TypeMenu
             else
	       ExecAndValidate
             fi
           else
             echo -e "\n\t\t$eclr Invalid Selection, $staticIPin is not within a range"
             echo -e "\t\t$eclr for the country city you selected.  Enter [s] to see"
             echo -e "\t\t$eclr useable IP ranges for your selected location. Please try again" 
	     sleep 3
             SetStaticIP
           fi
         else
             echo -e "\n\t\t$eclr $staticIPin is not a valid IP! Please try again"; sleep 2
             SetStaticIP
         fi;;
  esac
}
showSubnets()
{
  clear
  echo -e "$h1clr Search through the IP ranges below, use up and down arrows to search the list"
  echo -e "Then enter 'q' when you're done $iclr"
  sed '1d; s/\/[0-9][0-9],/ \- /' $rtrpath/$countrysel/$citysel.txt > /tmp/subnets.txt
  less /tmp/subnets.txt
  rm /tmp/subnets.txt
  SetStaticIP
}

PortMenu()
{
  MenuBanner 
  # Set initial variables, resets if user navigates back
  http=0
  https=0
  dns=0
  # Display user select data, data depends on original mainmenu selections.
  if [[ $opt == 1 ]]; then
    printf "\t\t$entclr%16s: $h1clr%-20s\n" "Country Selected" $countrysel
    printf "\t\t$entclr%16s: $h1clr%-20s\n" "City Selected" $citysel
    printf "\t\t$entclr%16s: $h1clr%-20s\n" "Number of IP's" $totalipssel
  fi
  # List Options, get user input, process the input.
  echo -e "\n\t$infoclr Set Ports to be redirected"
  echo -e "\t$optclr    1 )$valclr HTTP,HTTPS,DNS"
  echo -e "\t$optclr    2 )$valclr HTTP,HTTPS"
  echo -e "\t$optclr    3 )$valclr HTTP,DNS"
  echo -e "\t$optclr    4 )$valclr HTTPS,DNS"
  echo -e "\t$optclr    5 )$valclr HTTPS Only"
  echo -e "\t$optclr    6 )$valclr HTTP Only"
  echo -e "\t$optclr    7 )$valclr DNS Only"
  echo -e "\t$optclr    8 )$valclr Set Custom Ports"
  echo -e "$iclr"
  read -p "        Enter Selection Here: " ports
  case $ports in
    q|Q) exit 0;;
    b|B) if [[ $justAttackerIP == 1 ]]; then MainMenu; else NumIPsMenu; fi;;
      1) https=1;http=1;dns=1;AttackerMenu;;
      2) http=1;https=1;AttackerMenu;;
      3) http=1;dns=1;AttackerMenu;;
      4) https=1;dns=1;AttackerMenu;;
      5) https=1;AttackerMenu;;
      6) http=1;AttackerMenu;;
      7) dns=1;AttackerMenu;;
      8) CustomInfo;;
      *) echo -e "\n\t\t$eclr Invalid Selection, Please try again"; sleep 2
         PortMenu;;
  esac
}

CustomInfo()
{
  clear
  echo -e "\n\n\t$infoclr Setting Custom Ports requires using special scripts."
  echo -e "\t If you really want to do this, go back to the main menu and"
  echo -e "\t select options 2 \"Change Redirector IPs\".  follow that to"
  echo -e "\t set the redirector's IPs.  Then use the \"customredirection.sh\""
  echo -e "\t script to set custom ports.  You just have to fill in the "
  echo -e "\t the config file at /root/scripts/custom.txt first." 
  echo -e "\t However, if HTTPS, HTTP, and/or DNS is all you need, go back"
  echo -e "\t to the Port menu and finish building the redirector.\n"
  echo -e "\t$optclr    1)$valclr Go back the Main Menu"
  echo -e "\t$optclr    2)$valclr Go back to the Port Menu"
  echo -e "$iclr"
  read -p "      Enter a Selection Here:" answer
  case $answer in 
    q|Q) exit 0;;
      1) MainMenu;;
    b|B|2) PortMenu;;
      *) echo -e "\n\t\t$eclr Invalid Selection, Please try again"; sleep 2
         CustomInfo;;
  esac
}

AttackerMenu()
{
  MenuBanner 
  # Set initial variables, reset if user navigates back
  portsel=""
  # Get and display user selected information
  if [[ $https == 1 ]]; then portsel="https"; fi
  if [[ $http == 1 ]]; then portsel=$portsel" http"; fi
  if [[ $dns == 1 ]]; then portsel=$portsel" dns"; fi
  if [[ $opt == 1 ]]; then
    printf "\t\t$entclr%16s: $h1clr%-20s\n" "Country Selected" $countrysel
    printf "\t\t$entclr%16s: $h1clr%-20s\n" "City Selected" $citysel
    printf "\t\t$entclr%16s: $h1clr%-20s\n" "Number of IP's" $totalipssel
  fi
  if [[ $setattackip == 1 ]]; then
    printf "\t\t$entclr%16s: $h1clr%-20s\n" "Ports Selected" "$portsel"
  fi
  # Get user data, process selection
  echo -e "\n\t$infoclr Set the redirector to redirect to your Attack Box$iclr\n"
  read -p "       Enter your Attack box IP Here: " attackip 
  case $attackip in
    q|Q) exit 0;;
    b|B) PortMenu;;
      *) CheckIP $attackip
         if [[ $? -eq 0 ]]; then
           attackeripsel=$attackip
           ExecAndValidate
         else 
           echo -e "\n\t\t$eclr Invalid Selection, Please try again"; sleep 2
           AttackerMenu
         fi;;
  esac
}  

C2TypeMenu()
{
  MenuBanner
  # Sets initial variables, resets values if user navigates back.
  count=1
  # List options, get user input, process the input
  echo -e "\t$infoclr Select a base Cobalt Strike C2 Malleable profile$optclr"
  for folder in `ls $csc2path`; do
    printf "\t$optclr%3d )$valclr %-23s\n" $count $folder 
    let "count++";
  done
  echo -e "$iclr"
  read -p "        Please Enter Selection Here: " c2type 
  case $c2type in
    q|Q) exit 0;;
    b|B) MainMenu;;
      *) if (( $c2type >= 1 && $c2type < $count )) 2>/dev/null; then
           c2typesel=`ls $csc2path  | sed -n ${c2type}p`
           C2ProfileMenu
         else
           echo -e "\n\t\t$eclr Invalid Selection, Please try again"; sleep 2
           C2TypeMenu
         fi;;
  esac
}

C2ProfileMenu()
{
  MenuBanner
  # sets initial variables, resets values if user navigates back
  count=1
  # Get and display user selected items
  printf "\t\t$entclr%25s: $h1clr%-20s\n " "C2 Profile Type Selected" $c2typesel
  # List options, get user input, process the input
  echo -e "\n\t$infoclr Select a Profile$optclr"
  for file in `ls $csc2path/$c2typesel`; do
    printf "\t$optclr%3d )$valclr %-23s\n" $count $file
    let "count++";
  done
  echo -e "$iclr"
  read -p "        Please Enter Profile Here: " profile
  case $profile in
    q|Q) exit 0;;
    b|B) C2TypeMenu;;
      *) if (( $profile >= 1 && $profile< $count )) 2>/dev/null; then
           c2profilesel=`ls $csc2path/$c2typesel | sed -n ${profile}p`
           C2PasswordMenu      
         else
           echo -e "\n\t\t$eclr Invalid Selection, Please try again"; sleep 2
           C2ProfileMenu
         fi;;
   esac
}

C2PasswordMenu()
{
  MenuBanner
  # Get and display user selected items
  printf "\t\t$entclr%25s: $h1clr%-20s\n " "C2 Profile Type Selected" $c2typesel
  printf "\t\t$entclr%25s: $h1clr%-20s\n " "C2 Profile Selected" $c2profilesel
  # List options, get user input, process the input
  echo -e "\n\t$infoclr Next Set a Teamserver Password, this will be used to connect later$iclr"
  read -p "        Please Enter Password Here: " password
  case $password in
    q|Q) exit 0;;
    b|B) C2ProfileMenu;;
      *) if [[ $password != "" ]]; then
            ExecAndValidate      
          else
            echo -e "\n\t\t$eclr Invalid Selection, Password Can't be Null!"; sleep 2
            C2PasswordMenu
          fi;;
   esac
}
  
ExecAndValidate()
{
  MenuBanner
  # Get user selections and display them for confirmation
  case $opt in 
    1) echo -e "\n\t\t$entclr Setting up redirector using the following settings"
       hostnamein=`hostname`
       printf "\t\t$entclr%19s: $h1clr%-20s\n" "Redirector Hostname" $hostnamein;;
    2) echo -e "\n\t\t$entclr Setting up a Cobalt Strike TeamServer using the following settings";;
    3) echo -e "\n\t\t$entclr Setting up a Payload Host using the following settings";;
    4) echo -e "\n\t\t$entclr Changing Redirector IP's using the following settings";;
    5) echo -e "\n\t\t$entclr Changing Redirector destination IP using the following settings";;
    *) echo -e "\n\t\t$eclr Not sure how you broke the script, but you did!";;
  esac
  if [[ $setips == 1 ]]; then
    printf "\t\t$entclr%19s: $h1clr%-20s\n" "Country Selected" $countrysel
    printf "\t\t$entclr%19s: $h1clr%-20s\n" "City Selected" $citysel
    printf "\t\t$entclr%19s: $h1clr%-20s\n" "Number of IP's" $totalipssel
  fi
  if [[ $staticip == 1 ]]; then
    printf "\t\t$entclr%19s: $h1clr%-20s\n" "IP set to" $staticIPsel
  fi
  if [[ $randomip == 1 ]]; then
    echo -e "\t\t$entclr A random IP address will be generated." 
  fi
  if [[ $setattackip == 1 ]]; then
    printf "\t\t$entclr%19s: $h1clr%-20s\n" "Ports Selected" "$portsel"
    printf "\t\t$entclr%19s: $h1clr%-20s\n" "Attack Box IP" "$attackeripsel"
  fi
  if [[ $setcsts == 1 ]]; then
    printf "\t\t$entclr%25s: $h1clr%-20s\n " "C2 Profile Type Selected" $c2typesel
    printf "\t\t$entclr%25s: $h1clr%-20s\n " "C2 Profile Selected" $c2profilesel
  fi
  echo -e "\n\t\t$entclr This script will kill any running apache, nginx, or cobalt strike"
  echo -e "\t\t teamserver services and start the the correct services required.\n" 
  # Validate the user agrees 
  read -p "      Do you want to contine? press enter to continue or q to quit" answer
  case $answer in
    q|Q) exit 0;;
     *) continue;;
  esac 

  # Kill all services that would cause a conflict.
  case $opt in
    1|4|5) 
	  if [[ $https == 1 ]]; then
        lsof -n -i4TCP:443 | grep "LISTEN" | awk '{ print $2 }' | uniq | xargs -r kill
      fi
      if [[ $http == 1 ]]; then
	    lsof -n -i4TCP:80 | grep "LISTEN" | awk '{ print $2 }' | uniq | xargs -r kill 
      fi
      if [[ $dns == 1 ]]; then
        lsof -n -i4TCP:53 | grep "LISTEN" | awk '{ print $2 }' | uniq | xargs -r kill
        lsof -n -i4UDP:53 | awk 'FNR == 1 {next}{ print $2 }' | xargs -r kill
      fi;;
    2)  
	  lsof -n -i4TCP:443 | grep "LISTEN" | awk '{ print $2 }' | uniq | xargs -r kill
	  lsof -n -i4TCP:80 | grep "LISTEN" | awk '{ print $2 }' | uniq | xargs -r kill 
      lsof -n -i4TCP:53 | grep "LISTEN" | awk '{ print $2 }' | uniq | xargs -r kill
      lsof -n -i4UDP:53 | awk 'FNR == 1 {next}{ print $2 }' | xargs -r kill;;
    3)  
	  lsof -n -i4TCP:443 | grep "LISTEN" | awk '{ print $2 }' | uniq | xargs -r kill
	  lsof -n -i4TCP:80 | grep "LISTEN" | awk '{ print $2 }' | uniq | xargs -r kill;;
    *)  echo "Serious, how did you get there?";;
  esac
  
  # Build required configurations and start services
  if [[ $setips == 1 ]]; then 
    BuildIntConfig
    # disables IPv6
    sysctl net.ipv6.conf.all.disable_ipv6=1 1>/dev/null
    # deletes interface configuration and clears the routing table
    ip addr flush $intname && ip route flush table main
    # Restart networking services to read in new interface config
    echo -ne "\n\t$h1clr  Restarting Network Services Now...."
    service networking stop
    service networking start 
	echo -e "\t$h3clr  Finished!" 
  fi
  if [[ $setattackip == 1 ]]; then 
    BuildNGINXConfig
    systemctl start nginx
  fi
  if [[ $setpayloadhost == 1 ]]; then
    systemctl start apache2
  fi
  if [[ $setcsts == 1 ]]; then
    if [[ $staticip == 1 ]]; then
      echo "$cspath/teamserver $staticIPsel $passwordin $cspath/$c2typesel/$c2profilesel"; 
    else
      echo "$cspath/teamserver $randomIPsel $passwordin $cspath/$c2typesel/$c2profilesel"; 
    fi 
  fi
  # Finished, show completion screen and bridge info.
  clear
  MenuBanner
  echo -e "\n\n\t$h3clr Setup Complete!\n\n"
  if [[ $staticip == 1 ]]; then
    printf "\t\t$entclr%19s: $h1clr%-20s\n" "IP set to" $staticIPsel
  fi
  if [[ $randomip == 1 ]]; then
    printf "\t\t$entclr%19s: $h1clr%-20s\n" "IP set to" $randomIPsel
  fi

  if [[ $setips == 1 ]]; then
    echo -e "\t$h3clr  NOTE: Connect VM to the RGI Network Bridge listed below"
    echo -e "\n\t\t\t$h2clr $bridge \e[1;49m\n"
    echo -e "\t$h3clr Once connected to the bridge, follow these steps."
    echo -e "\n\t\t$valclr Step 1.$bclr Pinging the a.root server. i.e.  ping a.root"
    echo -e "\t\t$valclr Step 2.$bclr Copy ssh key to the a.root. i.e.  ssh-copy-id a.root"
    echo -e "\t\t\t\t$entclr NOTE: a.root's password: G10ba1internets"
    echo -e "\t\t\t\t$entclr If you get an error that the key already exists,"
    echo -e "\t\t\t\t$entclr don't worry it means its already added."
    if [[ $opt == 1 ]] || [[ $opt == 4 ]]; then
      echo -e "\t\t$valclr Step 3.$bclr Run /root/scripts/AssignDNS.sh"
      echo -e "\t\t\t\t$entclr NOTE: This script automatically generates domain names"
      echo -e "\t\t\t\t$entclr and registers the domains to your new redirector IP's\n"
    elif [[ $opt == 3 ]]; then
      echo -e "\t\t$valclr Step 3. $bclr Set a domain name in x/x then"
      echo -e "\t\t$valclr         $bclr run /root/scripts/setPayloadDNS.sh"
    fi 
  fi 
}

BuildNGINXConfig()
{
  echo -ne "\t$h1clr  Building NGINX.conf for redirection Now...."
  # Set path to temporary nginx config file
  nginxconf="/root/scripts/nginx.conf"
  # build initial file
  echo -e "worker_processes 1;" > $nginxconf
  echo -e "\nload_module /usr/lib/nginx/modules/ngx_stream_module.so;" >> $nginxconf
  echo -e "\nevents {\n\tworker_connections 1024;\n}" >> $nginxconf
  echo -e "\nstream {" >> $nginxconf
  # Build required streams
  if [[ $https == 1 ]]; then
    echo -e "\n\tupstream ssl {\n\t\tserver $attackeripsel:443;\n\t}" >> $nginxconf
    echo -e "\n\tserver {" >> $nginxconf
    while read p; do
      if [[ $p == \#* ]]; then continue; fi
      sip=`echo $p | cut -d/ -f1`
      echo -e "\t\tlisten $sip:443;" >> $nginxconf
    done</root/scripts/redirector_iplist.txt
    echo -e "\t\tproxy_pass ssl;\n\t}" >> $nginxconf
  fi
  if [[ $http == 1 ]]; then
    echo -e "\n\tupstream http {\n\t\tserver $attackeripsel:80;\n\t}" >> $nginxconf
    echo -e "\n\tserver {" >> $nginxconf
    while read p; do
      if [[ $p == \#* ]]; then continue; fi
      sip=`echo $p | cut -d/ -f1`
      echo -e "\t\tlisten $sip:80;" >> $nginxconf
    done</root/scripts/redirector_iplist.txt
    echo -e "\t\tproxy_pass http;\n\t}" >> $nginxconf
  fi
  if [[ $dns == 1 ]]; then
    echo -e "\n\tupstream dns {\n\t\tserver $attackeripsel:53;\n\t}" >> $nginxconf
    echo -e "\n\tserver {" >> $nginxconf
    while read p; do
      if [[ $p == \#* ]]; then continue; fi
      sip=`echo $p | cut -d/ -f1`
      echo -e "\t\tlisten $sip:53;" >> $nginxconf
    done</root/scripts/redirector_iplist.txt
    echo -e "\t\tproxy_pass dns;\n\t}" >> $nginxconf
    echo -e "\n\tserver {" >> $nginxconf
    while read p; do
      if [[ $p == \#* ]]; then continue; fi
      sip=`echo $p | cut -d/ -f1`	  
      echo -e "\t\tlisten $sip:53 udp;" >> $nginxconf
    done</root/scripts/redirector_iplist.txt
    echo -e "\t\tproxy_pass dns;\n\t}" >> $nginxconf
  fi
  echo -e "\n}" >> $nginxconf
  mv $nginxconf /etc/nginx/nginx.conf
}

BuildIntConfig()
{
  clear 
  MenuBanner
  # Let the user know script is working.
  echo -ne "\n\t$h1clr  Building IP's Now...."

  # Set common variables for script use
  hostnamein=`hostname`
  dnssrv="17.72.153.88"
  # gets the name of the interface
  intname=`ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}'`
  # Configuration file is built, now we process through it to create
  # a new interface config file.  This file will get moved to /etc/network/interfaces
  intfile="/root/scripts/int.tmp"
  # Set the name for the configuration file that will get built.
  IPfile="/root/scripts/redirector_iplist.txt"
  # get the selected backbone router file.
  brtrfile="$rtrpath/$countrysel/$routerfile"
  # pull network bridge information from file header. 
  bridge=`head -n 1 $brtrfile | cut -d : -f2`

  # initialize the configuration file.
  echo "# IP CONFIGURATION FILE GENERATED BY buildredirector.sh" > $IPfile
  echo "# Hostname:$hostnamein" >> $IPfile
  echo "# Set redirector to network Bridge: $bridge" >> $IPfile
  # Initializes the interfaces file 
  echo "# Interface file generated by buildredirector.sh " > $intfile
  echo "auto lo" >> $intfile
  echo -e "iface lo inet loopback\n" >> $intfile
  
  # Check if a static IP is passed by the CobaltStrike Teamserver or Payload server options.
  if [[ $staticip == 1 ]]; then
    echo "$staticIPin,$staticgatewayin" >> $IPfile
  else
    #process through to create random IPs
    # calc # of IP ranges within the backbone router file, subtract 1 for header comment line.
    rangecount=`cat $brtrfile | expr \`wc -l\` - 1`
    # see how many IP's per range will be needed to reach the select number of IPs
    factor=` expr $totalipssel / $rangecount`
    # Add 1 to the factor so we run over and not under.
    numips=` expr $factor + 1`
    count=0
    for y in `cat $brtrfile`
    do
      # Ignore comment lines or blank lines in the file.
      if [[ $y == \#* ]] || [[ $y == "" ]]; then continue; fi
      if [[ $count -ge $totalipssel ]]; then break; fi
      gateway=`echo $y | cut -d, -f1`
      gwyIP=`echo $gateway | cut -d/ -f1`
      # On the first pass, grab the first router IP and use as the gateway
      # NOTE: any of the backbone router IP's can be used as the gateway
      if [[ $count == 0 ]]; then
        echo "# REDIR Interface IP's are below" >> $IPfile
      fi
      # take router IP/CIDR from the backbone router file and break it down to components
      cidr=`echo $gateway | cut -d/ -f2`
      oct1=`echo $gwyIP | cut -d. -f1`
      oct2=`echo $gwyIP | cut -d. -f2`
      oct3=`echo $gwyIP | cut -d. -f3`
      oct4=`echo $gwyIP | cut -d. -f4`
      # Add one to the last oct as the starting IP range
      oct4plus1=` expr $oct4 + 1`
      # the mod is the remainder of the cidr divided by 8
      mod=` expr $cidr % 8`
      # the div is the whole number of times the cidr divides into 8
      div=` expr $cidr / 8`
      # process the mod and set the value to add to the target oct. Subnet math...
      case $mod in
        7) addval=1;;
        6) addval=3;;
        5) addval=7;;
        4) addval=15;;
        3) addval=31;;
        2) addval=63;;
        1) addval=127;;
        0) addval=255;;
      esac
      # Modify IP oct based on the div.
      # each one uses the shuf command, this generates random numbers set
      # by -n between two numbers. then puts the IP back together
      # attachs the CIDR back and saves it to the config file.
      case $div in
        3) octmod=` expr $oct4 + $addval - 2`;
           for x in `shuf -i $oct4plus1-$octmod -n $numips`; do
             if [[ $count == $totalipssel ]]; then break; fi
             echo $oct1.$oct2.$oct3.$x/$cidr,$gwyIP >> $IPfile
             let "count++"
           done;;
        2) octmod=` expr $oct3 + $addval`;
           for x in `shuf -i 1-254 -n $numips`; do 
             if [[ $count == $totalipssel ]]; then break; fi 
             randoct3=`shuf -i $oct3-$octmod -n 1`
             echo $oct1.$oct2.$randoct3.$x/$cidr,$gwyIP >> $IPfile
             let "count++"
           done;;
        1) octmod=` expr $oct2 + $addval`;
           for x in `shuf -i 1-254 -n $numips`; do 
             if [[ $count == $totalipssel ]]; then break; fi
             randoct2=`shuf -i $oct2-$octmod -n 1`
             randoct3=`shuf -i 0-255 -n 1`
             echo $oct1.$randoct2.$randoct3.$x/$cidr,$gwyIP >> $IPfile
             let "count++"
           done;;
        0) octmod=` expr $oct1 + $addval`;
           for x in `shuf -i 1-254 -n $numips`; do   
             if [[ $count == $totalipssel ]]; then break; fi
             randoct1=`shuf -1 $oct1-$octmod -n 1`
             randoct2=`shuf -i 0-255 -n 1`
             randoct3=`shuf -i 0-255 -n 1`
             echo $randoct1.$randoct2.$randoct3.$x/$cidr,$gwyIP >> $IPfile
             let "count++"
           done;;
      esac
    done
  fi
  #set loop variables.
  pass=0
  # Loops through the config file to create netplan yaml file
  while read p; do
    if [[ $p == \#* ]] || [[ $p == "" ]]; then continue; fi
    if [[ $pass -eq 0 ]]; then intnamein=$intname
    else intnamein=$intname:$pass
    fi  
    addrin=`echo $p | cut -d, -f1`
    gwyip=`echo $p | cut -d, -f2`
    if [[ $randomip == 1 ]]; then
      randomIPsel=`echo $addrin | cut -d/ -f1`
    fi
    echo "auto $intnamein" >> $intfile
    echo "iface $intnamein inet static" >> $intfile
    echo "  address $addrin" >> $intfile
    if [[ $pass -eq 0 ]]; then
      echo "  gateway $gwyip" >> $intfile
      echo "  dns-nameservers $dnssrv" >> $intfile
    fi
    let "pass++"
  done<$IPfile
  # replace interfaces file with newly created one
  mv $intfile /etc/network/interfaces
  echo -e "\t$h3clr  Finished!"
}

# script to check if a variable is a valid IP address
CheckIP() 
{
  local ip=$1
  if `ipcalc -c $ip | grep -q INVALID` 
  then return 1
  else return 0
  fi  
}
# Script execution actually starts here with a call to the MainMenu.
MainMenu

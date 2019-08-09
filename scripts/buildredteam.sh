#!/bin/bash
# Written by Chip McElvain 168COS
# Red Team infastructure multi-use set up script.  Uses backbone router information for IP configs
# stored in /root/backbonerouters to generate random IP's or set static IPs
# that can be used for red team.

# set initial variables for paths, files, and/or values
rtrpath="/root/backbonerouters"
cspath="/root/cobaltstrike"
tempIPfile="/tmp/iplist.txt"
IPfile="/root/scripts/IPList.txt"
tempintfile="/tmp/interface.txt"
intfile="/etc/network/interfaces"
csc2path="/root/cobaltstrike/Malleable-C2-Profiles"
dnsfile="/root/scripts/redteamDNS.txt"
RGIDNS="17.72.153.88"

# Set variable names to add color codes to menu displays.
white="\e[1;37m"
ltblue="\e[1;36m"
ltgray="\e[0;37m"
red="\e[1;31m"
green="\e[1;32m"
whiteonblue="\e[5;37;44m"
yellow="\e[1;33m"
default="\e[0m"

# The following is the logic flow of the functions
# -> MainMenu 
#   -> Option 1 Set up a NGINX Redirector
#     -> NeedIPsMenu            
#       -> CountryMenu
#         -> CityMenu
#           -> NumIPsMenu
#             -> PortMenu  <- Jump here if No to NeedIPsMenu  
#               -> RedirDestMenu
#                 ->  HostnameMenu   
#                   -> ExecAndValidate
#   -> Option 2 Set up a HAProxy Redirector
#     -> NeedIPsMenu
#       -> CountryMenu
#         -> CityMenu
#           -> NumIPsMenu
#             -> PortMenu  <- Jump here if NO to NeedIPsMenu
#               -> C2profilemenu
#                 -> RedirDestMenu
#                   -> HostnameMenu
#                     -> ExecAndValidate
#   -> Option 3 Set up a Cobalt Strike teamserver
#     -> NeedIPsCSMenu 
#       -> CountryMenu
#         -> CityMenu
#           -> SetIPOption  Optional side path -> SetStaticIP
#             -> csc2typeMenu  <-Jump here if no to NeedIPsCSMenu
#               -> csc2profileMenu
#                 -> csc2passwdMenu
#                   -> ExecAndValidate
#   -> Option 4 Set up payload host server
#     -> NeedIPsMenu -- Option "use current IPs" jumps to ExecAndValidate
#       -> CountryMenu
#         -> CityMenu
#           -> NumIPsMenu
#             -> ExecAndValidate  <- Jump here if no to NeedIPsMenu
#   -> Option 5 Just set some IP's
#     -> CountryMenu
#       -> CityMenu
#         -> NumIPsMenu
#           -> ExecAndValidate
#   -> Option 6 Change redirector destination IP and/or ports
#     -> PortMenu  
#       -> RedirDestMenu
#         -> ExecAndValidate

####   GENERAL FUNCTIONS FOR FORMATTING, STANDARD MESSAGES 
MenuBanner() 
{
  clear
  case $opt in
    1) bannertitle="Build a NGINX redirector";;
    2) bannertitle="Build a HAProxy Redirector";;
    3) bannertitle="Set up a Cobalt Strike Teamserver";;
    4) bannertitle="Set up a payload host";;
    5) bannertitle="Set up some IPs";;
    6) bannertitle="Modify Redirector ports/IPS";;
    *) bannertitle="Red Team Server Build Script";;
  esac
  printf "\n\t$ltblue %-60s %8s\n"  "$bannertitle" "<b>-Back"
  printf "\t$ltblue %60s %8s\n"  "" "<q>-Quit"
  ShowCurrentSettings
}

ShowCurrentSettings()
{
  if [[ ! -z $countrysel || ! -z $hostnamesel || ! -z $rediripsel || ! -z $profiletypesel  || ! -z $staticIPsel ]]; then
    echo -e "\t\t$white Current settings" 
  fi
  if [[ ! -z  $hostnamesel ]]; then SettingFormat "Hostname" "$hostnamesel"; fi
  if [[ ! -z $countrysel ]]; then SettingFormat "Country Selected" "$countrysel"; fi
  if [[ ! -z $citysel ]]; then SettingFormat "City Selected" "$citysel"; fi
  if [[ ! -z $totalipssel ]]; then SettingFormat "Number of IP's" "$totalipssel"; fi
  if [[ ! -z $staticIPsel ]]; then SettingFormat "IP set to" "$staticIPsel"; fi
  if [[ $randomipon == 1 ]]; then SettingFormat "IP set to" "Random"; fi
  if [[ ! -z $haprofile ]]; then SettingFormat "C2 Profile" "$haprofile"; fi
  if [[ ! -z $portsel ]]; then SettingFormat "Ports Selected" "$portsel"; fi
  if [[ ! -z $rediripsel ]]; then SettingFormat "Redir Dest IP" "$rediripsel"; fi
  if [[ ! -z $profiletypesel ]]; then SettingFormat "C2 Profile Type" "$profiletypesel"; fi
  if [[ ! -z $csc2profilesel ]]; then SettingFormat "C2 Profile" "$csc2profilesel"; fi
  if [[ ! -z $passwordsel ]]; then SettingFormat "Password" "$passwordsel"; fi
}

FormatOptions()
{
  local count="$1"
  local title="$2"
  printf "\t$ltblue%3d )$white %-23b\n" "$count" "$title"
}

SettingFormat()
{
  local title="$1"
  local value="$2"
  printf "$ltgray%25s: $green%-20b\n" "$title" "$value"
}

InputError()
{
  echo -e "\n\t\t$red Invalid Selection, Please try again"; sleep 2
}

CheckIP() 
{
  # Get passed IP address
  local ip=$1
  # Count number of "."'s to see if at least 4 octets were passed.
  octets=`awk -F. '{print NF-1}' <<< $ip`
  
  # if it passes an octet check, then use ipcalc to check if IP is a valid ipv4 IP
  # return 1 to indicate a failed test if it lacks 4 octets or isn't a valid IPv4
  # octet check in necessary since ipcalc will accept things like 1.1 or 1 
  # without returning invalid.
  if [[ $octets == 3 ]]
  then 
    if `ipcalc -c $ip | grep -iq INVALID`; then 
      return 1
    else 
      return 0
    fi
  else 
    return 1
  fi  
}

#### MENU FUNCTIONS FOR GETTING USER INPUT 
MainMenu()
{
  # Set initial variables, Resets values if user navigates back to the beginning
  opt=0;setips=0; setredirdest=0; setcsts=0; setpayloadhost=0; curipon=0; staticIPin=0; randomipon=0
  setnginx=0; sethaproxy=0; hostnamesel=; countrysel=; citysel=; totalipssel=; staticIPsel=; portsel=; 
  rediripsel=; profiletypesel=; csc2profilesel=; passwordin=;
  # Calls menu Banner
  MenuBanner
  # List options, get user input, process the input.
  FormatOptions 1 "Set up a NGINX redirector (http,https,DNS)"
  FormatOptions 2 "Set up a HAProxy redirector (${yellow}http and/or https only)"
  FormatOptions 3 "Set up a Cobalt Strike teamserver"
  FormatOptions 4 "Set up a payload host server"
  FormatOptions 5 "Just set some IP's"
  FormatOptions 6 "Change redirector desination IP and/or ports"
  echo -en "\n\t$ltblue Enter a Selection: $white" 
  read optin
  case $optin in
    1) opt=1; setnginx=1; NeedIPsMenu;;
    2) opt=2; sethaproxy=1; NeedIPsMenu;;
    3) opt=3; setcsts=1; NeedIPsCSMenu;;
    4) opt=4; setpayloadhost=1; NeedIPsMenu;;
    5) opt=5; NeedIPsMenu;;
    6) opt=6; setredirdest=1; PortMenu;;
    b|B) MainMenu;;
    q|Q) echo -e "$default"; exit 0;;
    *) InputError
       MainMenu;;
  esac
}

NeedIPsMenu()
{
  MenuBanner
  echo -e "\t$ltblue Do you want to use existing IPs or set new IPs?"
  FormatOptions 1 "Use existing IPs"
  FormatOptions 2 "Set new ones"
  echo -en "\n\t$ltblue Enter a Selection: $white"
  read optin
  case $optin in
    1)  curipon=1; 
        case $opt in
	  1|2) PortMenu;;
	  3) csc2typeMenu;;
	  4) ExecAndValidate;;
	esac;;
    2)  setips=1; CountryMenu;;
    b|B) MainMenu;;
    q|Q) echo -e "$default"; exit 0;;
    *) InputError
       NeedIPsMenu;;
  esac
}
	
NeedIPsCSMenu()
{
  MenuBanner
  intname=`ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}'`
  iplist=`ip a | grep $intname | grep inet | awk '{print $2}' | cut -d/ -f1`
  numip=`echo "$iplist" | wc -l`
  if [[ $numip == 1 ]]; then
    curIP=$iplist
    echo -e "\n\t$ltblue Your Current IP is $green $curIP"
    echo -e "\t$ltblue Do you want to use this or set a new IP?"
    FormatOptions 1 "use $curIP"
    FormatOptions 2 "Set a new one"
    echo -en "\n\t$ltblue Enter a Selection: $white"
    read optin 
    case $optin in
      1)  staticipon=1; staticIPsel=$curIP; csc2typeMenu;;
      2)  setips=1; CountryMenu;;
      b|B) MainMenu;;
      q|Q) echo -e "$default"; exit 0;;
      *) InputError
         NeedIPsCSMenu;;
    esac
  else 
    echo -e "\n\t$ltblue You currently have multiple IP's, you can pick one from the list"
    echo -e "\t$ltblue below, or elect to set a new one."
    echo -e "\t$yellow NOTE: Setting a new will remove all existing IPs."
    if [[ $numip -gt 20 ]]; then
      echo -e "\t$yellow Only the first 20 IP's are listed"
    fi
    echo -e ""   # added a return
    count=1
    for ip in $iplist 
    do	
      FormatOptions "$count" "$ip"
      let count++
      if [[ $count == 21 ]]; then break; fi
    done
    FormatOptions "$count" "${green}Set a new one" 
    echo -ne "\n\t$ltblue Enter a Selection: $white"
    read answer
    case $answer in
      $count) setips=1; CountryMenu;;
      b|B) MainMenu;;
      q|Q) echo -e "$default"; exit 0;;
      c|C) cp /dev/null $DNSconf; ManualDNS;; 
      d|D) ExecAndValidate;;
      *) if (( $answer >= 1 && $answer <= $count )) 2>/dev/null; then
           IPselected=`echo "$iplist" | sed -n ${answer}p`
           staticipon=1; staticIPsel=$IPselected; csc2typeMenu
         else 
	   InputError
           NeedIPsCSMenu
         fi;;
    esac
  fi
}	
 
CountryMenu()
{
  MenuBanner
  # Sets initial variables, resets values if user navigates back.
  count=1; countrysel=
  # List options, get user input, process the input
  echo -e "\t$ltblue Select a Country of Origin$ltblue"
  for folder in `ls $rtrpath`; do
    FormatOptions "$count" "$folder" 
    let "count++";
  done
  echo -ne "\n\t$ltblue Enter a Selection: $white"
  read country
  case $country in
    q|Q) echo -e "$default"; exit 0;;
    b|B) if [[ $opt == 3 ]]; then NeedIPsCSMenu;
         elif [[ $opt == 5 ]]; then MainMenu;
	 else NeedIPsMenu; fi;;
    *) if (( $country >= 1 && $country < $count )) 2>/dev/null; then
         countrysel=`ls $rtrpath  | sed -n ${country}p`
         CityMenu
       else
         InputError
         CountryMenu
       fi;;
  esac
}

CityMenu()
{
  MenuBanner
  # sets initial variables, resets values if user navigates back
  count=1; citysel=
  # List options, get user input, process the input
  echo -e "\n\t$ltblue Select a City$ltblue"
  for file in `ls $rtrpath/$countrysel | sed -e 's/\.txt//'`; do
    FormatOptions "$count" "$file"
    let "count++";
  done
  echo -ne "\n\t$ltblue Enter a Selection: $white"
  read City
  case $City in
    q|Q) echo -e "$default"; exit 0;;
    b|B) countrysel=; CountryMenu;;
    *) if (( $City >= 1 && $City < $count )) 2>/dev/null; then
         routerfile=`ls $rtrpath/$countrysel | sed -n ${City}p`
         citysel=`echo $routerfile | sed -e 's/\.txt//'`
         if (( $opt == 3 || $opt == 6 )); then SetIPOption
	 else NumIPsMenu
         fi
       else
         InputError
         CityMenu
       fi;;
   esac
}

NumIPsMenu()
{
  MenuBanner
  # List options, get user input, process the input 
  echo -e "\n\t$ltblue Select number of IPs you want to set. (Max: 200)"
  echo -ne "\t$ltblue Enter the number of IPs: $white"
  read totalips
  case $totalips in
    q|Q) echo -e "$default"; exit 0;;
    b|B) citysel=; CityMenu;;
    *) if (( $totalips >= 1 && $totalips <= 200 )) 2>/dev/null; then
         totalipssel=$totalips
         if (( $opt == 4 || $opt == 5 )); then ExecAndValidate 
         elif (( $opt == 1 || $opt == 2 )); then PortMenu 
         fi
       else
         InputError
         NumIPsMenu
       fi;;
  esac
}

SetIPOption()
{
  staticipon=0; randomipon=0
  MenuBanner
  # List options, get user input, process the input.
  if [[ $opt == 2 ]]; then
    echo -e "\n\t$ltblue Set the IP for your Cobalt Strike TeamServer."
  else
    echo -e "\n\t$ltblue Set the IP for your payload Server."
  fi
  FormatOptions 1 "Set a static IP"
  FormatOptions 2 "Set a random IP"
  echo -ne "\n\t$ltblue Enter a Selection: $white"
  read optin
  case $optin in
    1) staticipon=1; totalipssel=1; SetStaticIP;;
    2) randomipon=1; totalipssel=1; 
       if [[ $setcsts == 1 ]]; then
         csc2typeMenu
       else
         ExecAndValidate
       fi;;
    b|B) CityMenu;;
    q|Q) echo -e "$default"; exit 0;;
    *) InputError
       SetIPOption;;
  esac
}

SetStaticIP()
{
  MenuBanner
  if [[ $opt == 2 ]]; then
    echo -e "\n\t$ltblue Set your static IP for your Cobalt Strike TeamServer."
  else
    echo -e "\n\t$ltblue Set your static IP for your payload Server."
  fi
  echo -e "\t$ltblue enter [s] to see ip ranges for the country/city selected."
  echo -ne "\n\t$ltblue Enter a Static IP: $white"
  read sIPin
  case $sIPin in
    q|Q) echo -e "$default"; exit 0;;
    b|B) SetIPOption;;
    s|S) showSubnets;;
    *)  CheckIP $sIPin
        if [[ $? -eq 0 ]]; then
          for x in `cat $rtrpath/$countrysel/$citysel.txt`; do
            if [[ $x == \#* ]]; then continue; fi
            gateway=`echo $x | cut -d, -f1`
            subnet=`echo $gateway | cut -d/ -f2`
            gwmin=`echo $gateway | cut -d/ -f1`
            ipmin=`ipcalc $sIPin/$subnet | grep HostMin | tr -s ' ' | cut -d ' ' -f2`
            if [[ $gwmin == $ipmin ]]; then 
              staticgatewayin=$gwmin
              staticIPin=$sIPin/$subnet
              staticIPsel=$sIPin
              echo "valid IP : $staticIPin will use $staticgatewayin"
              found="yes"
              break;
            fi
          done
          if [[ $found == "yes" ]]; then
            if [[ $setcsts == 1 ]]; then
              csc2typeMenu
            else	
              ExecAndValidate
            fi
          else
            echo -e "\n\t\t$red Invalid Selection, $staticIPin is not within a range"
            echo -e "\t\t$red for the country city you selected.  Enter [s] to see"
            echo -e "\t\t$red useable IP ranges for your selected location. Please try again" 
            sleep 3
            SetStaticIP
          fi
        else
          echo -e "\n\t\t$red $staticIPin is not a valid IP! Please try again"; sleep 2
          SetStaticIP
        fi;;
  esac
}

PortMenu()
{
  MenuBanner 
  # Set initial variables, resets if user navigates back
  http=0; https=0; dns=0; curports=; checkfor=
  # Check if the server is already preforming redirection.  If so
  # tell the user what ports it's already redirecting.
  if (( $opt == 6 )); then
    if `service nginx status | grep -q "(running)"`; then 
      setnginx=1
      checkfor=NGINX
    elif `service haproxy status | grep -q "(running)"`; then 
      sethaproxy=1
      checkfor=HAProxy
    fi
    if [[ ! -z $checkfor ]]; then
      if `netstat -plant | grep -i $checkfor | grep -q ":53 "`; then curports="DNS"; fi
      if `netstat -plant | grep -i $checkfor | grep -q ":80 "`; then curports="HTTP "$curports; fi
      if `netstat -plant | grep -i $checkfor | grep -q ":443 "`; then curports="HTTPS "$curports; fi
    fi
    if [[ ! -z $curports ]]; then
      SettingFormat "Current Redir" "$checkfor"
      SettingFormat "Current ports" "$curports" 
    else
      SettingFormat "Current Redir" "$yellow Not configured"
      echo -e "\n\n\t$yellow This option isn't available.  There isn't a running redirector."
      echo -e "\t Press retun to go back to Main Menu$white"
      read ans
      MainMenu
      exit
    fi
  fi
  # List Options, get user input, process the input.
  echo -e "\n\t$ltblue Set Ports to be redirected"
  if [[ $setnginx == 1 ]]; then 
    FormatOptions 1 "HTTP, HTTPS" 
    FormatOptions 2 "HTTP only"
    FormatOptions 3 "HTTPS only"  
    FormatOptions 4 "HTTP, HTTPS, DNS" 
    FormatOptions 5 "HTTP, DNS"
    FormatOptions 6 "HTTPS, DNS"
    FormatOptions 7 "DNS only"
  elif [[ $sethaproxy == 1 ]]; then 
    FormatOptions 1 "HTTP, HTTPS"
    FormatOptions 2 "HTTP only"
    FormatOptions 3 "HTTPS only"
  fi	
  echo -ne "\n\t$ltblue Enter a Selection: $white"
  read optin
  case $optin in
    q|Q) echo -e "$default"; exit 0;;
    b|B) if [[ $opt == 6 ]]; then 
           MainMenu
         else 
           totalipssel=; NumIPsMenu 
         fi
	 exit;;
    1) https=1; http=1;;
    2) http=1;;
    3) https=1;;
    4) if [[ $opt == 2 ]]; then InputError; PortMenu; else https=1; http=1; dns=1; fi;;
    5) if [[ $opt == 2 ]]; then InputError; PortMenu; else http=1; dns=1; fi;;
    6) if [[ $opt == 2 ]]; then InputError; PortMenu; else https=1; dns=1; fi;;
    7) if [[ $opt == 2 ]]; then InputError; PortMenu; else dns=1; fi;;
    *) InputError
       PortMenu;;
  esac
  # Set initial variables, reset if user navigates back
  portsel=""
  # Get and display user selected information
  if [[ $dns == 1 ]]; then portsel="dns"; fi
  if [[ $http == 1 ]]; then portsel="http "$portsel; fi
  if [[ $https == 1 ]]; then portsel="https "$portsel; fi
  RedirDestMenu
}

RedirDestMenu()
{
  MenuBanner
  curredirIP=  
  # Get current redirector IP
  if [[ $setnginx == 1 ]]; then
    curredirIP=`grep -m 1 "# Server:" /etc/nginx/nginx.conf | awk -F: '{print$2}'`
  elif [[ $sethaproxy == 1 ]]; then 
    curredirIP=`grep -m 1 "server teamserver" /etc/haproxy/haproxy.cfg | awk '{print$3}' | cut -d: -f1`
  fi
  if [[ $curredirIP != "" ]]; then
    usecurIP=$curredirIP
    echo -e "\n\t$ltblue The current redirection IP is$green $usecurIP$ltblue To use this IP, just press enter."
    echo -e "\t To change it enter a new IP below"
  fi
  echo -ne "\n\t$ltblue Enter the IP you want to redirect to Here: $white"
  read redirip 
  case $redirip in
    q|Q) echo -e "$default"; exit 0;;
    b|B) portsel=; PortMenu; exit;;
    "") rediripsel=$usecurIP;;
    *) rediripsel=$redirip;;
  esac
  CheckIP $rediripsel
  if [[ $? -eq 0 ]]; then
    if [[ $opt == 6 ]]; then 
      if [[ $setnginx == 1 ]]; then ExecAndValidate;
      elif [[ $sethaproxy == 1 ]]; then GetC2ProfileMenu;
      fi
    else
      HostnameMenu
    fi
  else 
    InputError
    RedirDestMenu
  fi
}  

GetC2ProfileMenu()
{
  haprofile=
  MenuBanner
  curprofile=`grep Malleable /etc/haproxy/haproxy.cfg | cut -d: -f2`
  if [[ ! -z $curprofile ]]
  then
    SettingFormat "Current Profile" "$curprofile"
    echo -e "\n\t$blue Just press Enter to use existing profile, otherwise"
  else
    echo ""
  fi
  count=1
  echo -e "\t$yellow NOTE: In order for this script to set up HAProxy for your custom C2, please"
  echo -e "\t read the HAProxy section of the /root/readme.txt\n"
  echo -e "\t$ltblue Please select the C2 Profile that this redirector will be used for"
  for i in `ls $csc2path`; do
    for x in `ls $csc2path/$i`; do
      FormatOptions "$count" "$i $x"
      profarray[$count]=$x
      let "count++";
    done
  done
  echo -ne "\n\t$ltblue Enter a Selection Here: $white"
  read optin
  case $optin in 
    q|Q) echo -e "$default"; exit 0;;
    b|B) redirtypemenu;;
     "") haprofile=$curprofile; ExecAndValidate;; 
      *) if (($optin >= 1 & $optin < $count )) 2>/dev/null; then
           haprofile=${profarray[$optin]}
           ExecAndValidate
         else
           InputError
           GetC2ProfileMenu
         fi;;
  esac
}

HostnameMenu()
{
  MenuBanner
  chostname=`hostname`
  rnum=`shuf -i 1000-9999 -n 1`
  if [[ -z $citysel ]]; then
    rhostname="redteam-"$rnum
  else
    rhostname=$citysel-$rnum
  fi
  echo -e "\n\t$ltblue Set a unique hostname. (alphanumeric Only)"
  echo -e "\t$yellow NOTE: The hostname is used to identify DNS records related to this server. \n"
  FormatOptions 1 "Keep the existing:$green $chostname"
  FormatOptions 2 "Use randomly generared:$green $rhostname"
  FormatOptions 3 "Create your own"
  echo -ne "\n\t$ltblue  Enter a Selection: $white"
  read ans
  case $ans  in
    q|Q) echo -e "$default"; exit 0;;
    b|B) rediripsel=; RedirDestMenu;;
    1) hostnamesel=`hostname`;;
    2) hostnamesel=$rhostname;;
    3) SetHostname; exit;;
    *) InputError; HostnameMenu; exit;;
  esac 
  if [[ $opt == 2 ]]; then GetC2ProfileMenu;
  else ExecAndValidate; fi     
}

SetHostname()
{
  MenuBanner
  echo -ne "\n\t$ltblue Enter a unique hostname here (alphanumeric Only): $white"
  read hostin
  case $hostin in
    q|Q) echo -e "$default"; exit 0;;
    b|B) hostnamesel=; HostnameMenu;;
     "") echo -e "\n\t$red Hostname can't be blank"; sleep 2; SetHostname;;
      *)  if ! [[ $hostin =~ [^a-zA-Z0-9] ]]; then
            hostnamesel=$hostin
            ExecAndValidate
          else
            InputError
            SetHostname
          fi;;
  esac 
}

csc2typeMenu()
 {
  MenuBanner
  # Sets initial variables, resets values if user navigates back.
  count=1
  # List options, get user input, process the input
  echo -e "\n\t$ltblue Select a base Cobalt Strike C2 Malleable profile$ltblue"
  for folder in `ls $csc2path`; do
    FormatOptions "$count" "$folder" 
    let "count++";
  done
  echo -ne "\n\t$ltblue Enter a Selection Here: $white"
  read profiletype 
  case $profiletype in
    q|Q) echo -e "$default"; exit 0;;
    b|B) staticIPsel=; randomipon=0; NeedIPsCSMenu;;
      *) if (( $profiletype >= 1 && $profiletype < $count )) 2>/dev/null; then
           profiletypesel=`ls $csc2path  | sed -n ${profiletype}p`
           csc2profileMenu
         else
           InputError
           csc2typeMenu
         fi;;
  esac
}

csc2profileMenu()
{
  MenuBanner
  # sets initial variables, resets values if user navigates back
  count=1
  # List options, get user input, process the input
  echo -e "\n\t$ltblue Select a Profile$ltblue"
  pcount=`ls $csc2path/$profiletypesel | wc -l`
  if [[ $pcount -le 0 ]]; then
    echo -e "\t$red Sorry there are no profiles listed in"
    echo -e "\t$csc2path/$profiletypesel"
    echo -en "\t$ltblue Press b to go back and try another profile type$white"
  else
    for file in `ls $csc2path/$profiletypesel | sed -e 's/\.txt//'`; do
      FormatOptions "$count" "$file"
      let "count++";
    done
    echo -ne "\n\t$ltblue Enter Profile Here: $white"
  fi
  read profile
  case $profile in
    q|Q) echo -e "$default"; exit 0;;
    b|B) profiletypesel=; csc2typeMenu;;
      *) if (( $profile >= 1 && $profile< $count )) 2>/dev/null; then
           csc2profilesel=`ls $csc2path/$profiletypesel | sed -n ${profile}p`
           csc2passwdMenu     
         else
           InputError
           csc2profileMenu
         fi;;
   esac
}

csc2passwdMenu()
{
  MenuBanner
  # List options, get user input, process the input
  echo -e "\n\t$ltblue Next Set a Teamserver Password, this will be used to connect later"
  echo -ne "\n\t$ltblue Enter Password Here: $white"
  read passwordin
  case $passwordin in
    q|Q)  echo -e "$default"; exit 0;;
    b|B)  csc2profilesel=; csc2profileMenu;;
    *\ *) echo -e "\n\t\t$red Password can't have spaces, Please try again"; sleep 2
          csc2passwdMenu;;
     "")  echo -e "\n\t\t$red Password can't be blank, Please try again"; sleep 2
          csc2passwdMenu;;
      *)  passwordsel=$passwordin; ExecAndValidate;;
   esac
}
  
#######################  FINAL SCRIPT EXECTUION FUNCTION ########################
ExecAndValidate()
{
  MenuBanner
  # Get user selections and display them for confirmation
  case $opt in 
    1) echo -e "\n\t$ltblue Setting up a NGINX redirector using the above settings";;
    2) echo -e "\n\t$ltblue Setting up a HAProxy redirector using the above settings";;
    3) echo -e "\n\t$ltblue Setting up a Cobalt Strike TeamServer using above settings";;
    4) echo -e "\n\t$ltblue Setting up a Payload Host using the above settings";;
    5) echo -e "\n\t$ltblue Setting server IP's using the above settings";;
    6) echo -e "\n\t$ltblue Changing Redirector destination IP using the above settings";;
    *) echo -e "\n\t$red Not sure how you broke the script, but you did! opt=$opt";;
  esac
  # based on main menu selection, execute set scripts.
  echo -ne "\t$ltblue Do you want to continue? Press enter to continue or q to quit"
  read answer
  case $answer in
    q|Q) echo -e "$default"; exit 0;;
    b|B) case $opt in
           1|2) hostnamesel=; HostnameMenu;;
             3) passwordsel=; csc2passwdMenu;;
             4) if (( $curipon == 1 )); then
                  curipon=0; NeedIPsMenu
                else 
                  totalipssel=; NumIPsMenu
                fi;;
             5) totalipssel=; NumIPsMenu;;
             6) rediripsel=; RedirDestMenu;;
         esac
         exit;;
      *) MenuBanner;;
  esac 

  # Kill all services that would cause a conflict.
  service haproxy stop
  service nginx stop
  service apache2 stop
  # Catchall for anything else on required ports
  lsof -n -i4TCP:443 | grep "LISTEN" | awk '{print$2}' | uniq | xargs -r kill 2>/dev/null
  lsof -n -i4TCP:80 | grep "LISTEN" | awk '{print$2}' | uniq | xargs -r kill 2>/dev/null
  lsof -n -i4TCP:53 | grep "LISTEN" | awk '{print$2}' | uniq | xargs -r kill 2>/dev/null
  lsof -n -i4UDP:53 | awk 'FNR == 1 {next}{print$2}' | xargs -r kill 2>/dev/null
  # add a return to seperate script execution output.
  echo "" 
  # Build required configurations and start services
  if [[ $hostnamesel != "" ]]; then hostname $hostnamesel; fi
  if [[ $setips == 1 ]]; then 
    echo -ne "\t$yellow  Building IP's Now...."
    BuildIntConfig
    echo -e "$green Finished!"
    mv $tempintfile $intfile
    mv $tempIPfile $IPfile
    # disables IPv6
    sysctl net.ipv6.conf.all.disable_ipv6=1 1>/dev/null
    # deletes interface configuration and clears the routing table
    ip addr flush $intname && ip route flush table main
    # Restart networking services to read in new interface config
    echo -ne "\t$yellow  Restarting Network Services Now...."
    service networking stop 2>/dev/null
    service networking start 2>/dev/null
    echo -e "$green Finished!"
    echo -e "\t$green  Set /etc/resolv.conf to $RGIDNS"
    echo "nameserver $RGIDNS" > /etc/resolv.conf
    # delete any pre-existing DNS config file since the IP's have changed.
    if [ -s $dnsfile ]; then rm $dnsfile; fi
  fi
  if [[ $setnginx == 1 ]]; then 
    echo -ne "\t$yellow  Building NGINX.conf for redirection Now...."
    BuildNGINXConfig
    echo -e "$green Finished!"
    echo -ne "\t$yellow  Starting NGINX Now...."
    mv $nginxconf /etc/nginx/nginx.conf
    systemctl start nginx
    echo -e "$green Finished!"
  elif [[ $sethaproxy == 1 ]]; then
    echo -ne "\t$yellow  Building haproxy.cfg for redirection Now...."
    BuildHAProxyConfig
    echo -e "$green Finished!"
    echo -ne "\t$yellow  Starting HAProxy now...."
    mv $haproxyconf /etc/haproxy/haproxy.cfg
    systemctl start haproxy
    echo -e "$green Finished!"
  elif [[ $setpayloadhost == 1 ]]; then
    echo -ne "\t$yellow  Starting Apache2 Now...."
    systemctl start apache2
    echo -e "$green Finished!"
  elif [[ $setcsts == 1 ]]; then 
    echo "#!/bin/bash" > /root/start_teamserver.sh
    echo "cd $cspath" >> /root/start_teamserver.sh
    if [[ $staticipon == 1 ]]; then
      echo "./teamserver $staticIPsel $passwordin $csc2path/$profiletypesel/$csc2profilesel" >> /root/start_teamserver.sh
      printf "\t\t$ltgray%19s: $yellow%-20s\n" "IP set to" $staticIPsel
    else
      echo "./teamserver $randomIPsel $passwordin $csc2path/$profiletypesel/$csc2profilesel" >> /root/start_teamserver.sh
      printf "\t\t$ltgray%19s: $yellow%-20s\n" "IP set to" $randomIPsel
    fi
    echo -e "\n\t$green Starting Cobalt Strike Teamserver now.\n"
    echo -e "\t$white Press$yellow ctrl+c$white to kill teamserver.  Run$yellow /root/start_teamserver.sh$white to relaunch"
    echo -e "\t\t$green C2 profile: $yellow $profiletypesel - $csc2profilesel" 
    echo -e "\t\t$green Password:$yellow $passwordin\n"
    chmod 755 /root/start_teamserver.sh
    /root/start_teamserver.sh
  fi
  # Finished, show completion screen and bridge info.
  if [[ $setips == 1 ]]; then
    echo -e "\t$green NOTE: Connect VM to the RGI Network Bridge listed below"
    echo -e "\n\t\t\t$whiteonblue $bridge \e[1;49m\n"
  fi
  if (( $opt != 3 || $opt != 6 )); then
    echo -e "\t$green Follow these steps to assign DNS records to your IPs."
    echo -e "\n\t$white Step 1.$ltblue Pinging the a.root server. i.e.  ping a.root"
    echo -e "\t$white Step 2.$ltblue Copy ssh key to the a.root. i.e.  ssh-copy-id a.root"
    echo -e "\t\t$ltgray NOTE: a.root's password:$yellow G10ba1internets"
    echo -e "\t\t$ltgray If you get an error that the key already exists,"
    echo -e "\t\t$ltgray don't worry it means its already added."
    echo -e "\t$white Step 3.$ltblue Run /root/scripts/ManageDNS.sh"
    echo -e "\t\t$ltgray NOTE: This script allows you to set your own domain names"
    echo -e "\t\t or it can also automatically generate domain names"
    echo -e "\t\t Then it will register the domains to your IP's"
    echo -e "\t\t automatically on the RGI root DNS servers \n" 
  fi
  echo -e "$default" 
}

###################################### BUILD FUNCTIONS ############################################
showSubnets()
{
  clear
  echo -e "$green Search through the IP ranges below, use up and down arrows to search the list"
  echo -e "Then enter 'q' when you're done $white"
  sed '1d; s/\/[0-9][0-9],/ \- /' $rtrpath/$countrysel/$citysel.txt > /tmp/subnets.txt
  less /tmp/subnets.txt
  rm /tmp/subnets.txt
  SetStaticIP
}

BuildHAProxyConfig()
{
  # set path to temporary haproxy config file
  haproxyconf="/tmp/haproxy.cfg"
  # Build initial file
  echo -e "# HAProxy configured by buildredteam.sh script" > $haproxyconf
  if [[ ! -z $haprofile ]]; then
    echo -e "# Configured for Malleable C2 Profile:$haprofile" >> $haproxyconf
  fi
  echo -e "global" >> $haproxyconf
  echo -e "  log 127.0.0.1 local2 debug" >> $haproxyconf
  echo -e "  maxconn 2000" >> $haproxyconf
  echo -e "  user haproxy" >> $haproxyconf
  echo -e "  group haproxy" >> $haproxyconf
  echo -e "defaults" >> $haproxyconf
  echo -e "  log     global" >> $haproxyconf
  echo -e "  mode    http" >> $haproxyconf
  echo -e "  option  httplog" >> $haproxyconf
  echo -e "  option  dontlognull" >> $haproxyconf
  echo -e "  retries 3" >> $haproxyconf
  echo -e "  option  redispatch" >> $haproxyconf
  echo -e "  timeout connect  5000" >> $haproxyconf
  echo -e "  timeout client  10000" >> $haproxyconf
  echo -e "  timeout server  10000" >> $haproxyconf
  echo -e "  log-format frontend:%f/%H/%fi:%fp\ backend:%b\ client:%ci:$cp\ GMT:%T\ useragent:%[capture.req.hdr(1)]\ body:%[capture.req.hdr(0)]\ request:%r" >> $haproxyconf
  if [[ $https == 1 ]]; then 
    echo -e "\nfrontend www-https" >> $haproxyconf
    echo -e "  option http-buffer-request" >> $haproxyconf
    echo -e "  declare capture request len 40000" >> $haproxyconf
    echo -e "  http-request capture req.body id 0" >> $haproxyconf
    echo -e "  capture request header User-Agent len 512" >> $haproxyconf
    echo -e "  log /dev/log local2 debug" >> $haproxyconf
    echo -e "  bind :443 ssl crt /etc/haproxy/haproxy.pem" >> $haproxyconf
    echo -e "  reqadd X-Forwarded-Proto:\ https" >> $haproxyconf
    # add code to insert acl based on teamserver profile
    if [[ ! -z $haprofile ]]; then
      for i in `grep "set uri" $csc2path/*/$haprofile  | awk -F '"' '{print$2}'`; do
        echo -e "  acl path_cs path -m beg $i" >> $haproxyconf
      done 
      echo -e "  acl path_cs path_reg ^/[a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9]$" >> $haproxyconf
      echo -e "  use_backend cobaltstrike-https if path_cs" >> $haproxyconf
      echo -e "  default_backend www-decoy" >> $haproxyconf
    else 
      echo -e " default_backend cobaltstrike-https" >> $haproxyconf
    fi
    echo -e "  timeout client 1m" >> $haproxyconf
    echo -e "\nbackend cobaltstrike-https" >> $haproxyconf
    echo -e "  option forwardfor" >> $haproxyconf
    echo -e "  server teamserver $rediripsel:443 ssl verify none" >> $haproxyconf	
  fi
  if [[ $http == 1 ]]; then
    echo -e "\nfrontend www-http" >> $haproxyconf
    echo -e "  mode http" >> $haproxyconf
    echo -e "  option http-buffer-request" >> $haproxyconf
    echo -e "  declare capture request len 40000" >> $haproxyconf
    echo -e "  http-request capture req.body id 0" >> $haproxyconf
    echo -e "  capture request header User-Agent len 512" >> $haproxyconf
    echo -e "  log /dev/log local2 debug" >> $haproxyconf
    echo -e "  bind :80" >> $haproxyconf
    echo -e "  reqadd X-Forwarded-Proto:\ http" >> $haproxyconf
    # add code to insert acl based on teamserver profile
    if [[ ! -z $haprofile ]]; then
      for i in `grep "set uri" $csc2path/*/$haprofile  | awk -F '"' '{print$2}'`; do
        echo -e "  acl path_cs path -m beg $i" >> $haproxyconf
      done 
      echo -e "  acl path_cs path_reg ^/[a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9][a-zA-Z0-9]$" >> $haproxyconf
      echo -e "  use_backend cobaltstrike-http if path_cs" >> $haproxyconf
      echo -e "  default_backend www-decoy" >> $haproxyconf
    else 
      echo -e " default_backend cobaltstrike-http" >> $haproxyconf
    fi
    echo -e "  timeout client 1m" >> $haproxyconf
    echo -e "\nbackend cobaltstrike-http" >> $haproxyconf
    echo -e "  option forwardfor" >> $haproxyconf
    echo -e "  server teamserver $rediripsel:80" >> $haproxyconf	
  fi
  echo -e "\nbackend www-decoy" >> $haproxyconf
  echo -e "  mode http" >> $haproxyconf
  echo -e "  server critter www.critter.com:80" >> $haproxyconf
}

BuildNGINXConfig()
{
  # Set path to temporary nginx config file
  nginxconf="/tmp/nginx.conf"
  # build initial file
  echo -e "# NGINX configured by buildredteam.sh script" > $nginxconf
  echo -e "# Server: $rediripsel" >> $nginxconf
  echo -e "worker_processes 5;" >> $nginxconf
  echo -e "pid /var/run/nginx.pid;" >> $nginxconf
  echo -e "error_log /var/log/nginx.error_log info;" >> $nginxconf
  echo -e "\nload_module /usr/lib/nginx/modules/ngx_stream_module.so;" >> $nginxconf
  echo -e "\nevents {\n\tworker_connections 1024;\n}" >> $nginxconf
  echo -e "\nstream {" >> $nginxconf
  # Build required streams
  if [[ $https == 1 ]]; then
    echo -e "\n\tupstream ssl {\n\t\tserver $rediripsel:443;\n\t}" >> $nginxconf
    echo -e "\n\tserver {" >> $nginxconf
    while read p; do
      if [[ $p == \#* ]]; then continue; fi
      sip=`echo $p | cut -d/ -f1`
      echo -e "\t\tlisten $sip:443;" >> $nginxconf
    done<$IPfile
    echo -e "\t\tproxy_pass ssl;\n\t}" >> $nginxconf
  fi
  if [[ $http == 1 ]]; then
    echo -e "\n\tupstream http {\n\t\tserver $rediripsel:80;\n\t}" >> $nginxconf
    echo -e "\n\tserver {" >> $nginxconf
    while read p; do
      if [[ $p == \#* ]]; then continue; fi
      sip=`echo $p | cut -d/ -f1`
      echo -e "\t\tlisten $sip:80;" >> $nginxconf
    done<$IPfile
    echo -e "\t\tproxy_pass http;\n\t}" >> $nginxconf
  fi
  if [[ $dns == 1 ]]; then
    echo -e "\n\tupstream dns {\n\t\tserver $rediripsel:53;\n\t}" >> $nginxconf
    echo -e "\n\tserver {" >> $nginxconf
    while read p; do
      if [[ $p == \#* ]]; then continue; fi
      sip=`echo $p | cut -d/ -f1`
      echo -e "\t\tlisten $sip:53;" >> $nginxconf
    done<$IPfile
    echo -e "\t\tproxy_pass dns;\n\t}" >> $nginxconf
    echo -e "\n\tserver {" >> $nginxconf
    while read p; do
      if [[ $p == \#* ]]; then continue; fi
      sip=`echo $p | cut -d/ -f1`	  
      echo -e "\t\tlisten $sip:53 udp;" >> $nginxconf
    done<$IPfile
    echo -e "\t\tproxy_pass dns;\n\t}" >> $nginxconf
  fi
  echo -e "\n}" >> $nginxconf
}

BuildIntConfig()
{
  # Set common variables for script use
  hostnamein=`hostname`
  dnssrv="17.72.153.88"
  # gets the name of the interface
  intname=`ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}'`
  # Configuration file is built, now we process through it to create
  # a new interface config file.  This file will get moved to /etc/network/interfaces
  # Set the name for the configuration file that will get built.
  # get the selected backbone router file.
  brtrfile="$rtrpath/$countrysel/$routerfile"
  # pull network bridge information from file header. 
  bridge=`head -n 1 $brtrfile | cut -d : -f2`

  # initialize the configuration file.
  echo "# IP CONFIGURATION FILE GENERATED BY buildredirector.sh" > $tempIPfile
  echo "# Hostname:$hostnamein" >> $tempIPfile
  echo "# Set redirector to network Bridge: $bridge" >> $tempIPfile
  # Initializes the interfaces file 
  echo "# Interface file generated by buildredirector.sh " > $tempintfile
  echo "auto lo" >> $tempintfile
  echo -e "iface lo inet loopback\n" >> $tempintfile
  
  # Check if a static IP is passed by the CobaltStrike Teamserver or Payload server options.
  if [[ $staticipon == 1 ]]; then
    echo "$staticIPin,$staticgatewayin" >> $tempIPfile
  else
    #process through to create random IPs
    # calc # of IP ranges within the backbone router file, subtract 1 for header comment line.
    rangecount=`cat $brtrfile | expr \`wc -l\` - 1`
    sleep 5
    # see how many IP's per range will be needed to reach the select number of IPs
    factor=` expr $totalipssel / $rangecount`
    # Add 1 to the factor so we run over and not under.
    numips=` expr $factor + 1`
    count=0
    while read y; do
      # Ignore comment lines or blank lines in the file.
      if [[ $y == \#* ]] || [[ $y == "" ]]; then continue; fi
      if [[ $count -ge $totalipssel ]]; then break; fi
      gateway=`echo $y | cut -d, -f1`
      gwyIP=`echo $gateway | cut -d/ -f1`
      # On the first pass, grab the first router IP and use as the gateway
      # NOTE: any of the backbone router IP's can be used as the gateway
      if [[ $count == 0 ]]; then
        echo "# REDIR Interface IP's are below" >> $tempIPfile
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
             echo $oct1.$oct2.$oct3.$x/$cidr,$gwyIP >> $tempIPfile
             let "count++"
           done;;
        2) octmod=` expr $oct3 + $addval`;
           for x in `shuf -i 1-254 -n $numips`; do 
             if [[ $count == $totalipssel ]]; then break; fi 
             randoct3=`shuf -i $oct3-$octmod -n 1`
             echo $oct1.$oct2.$randoct3.$x/$cidr,$gwyIP >> $tempIPfile
             let "count++"
           done;;
        1) octmod=` expr $oct2 + $addval`;
           for x in `shuf -i 1-254 -n $numips`; do 
             if [[ $count == $totalipssel ]]; then break; fi
             randoct2=`shuf -i $oct2-$octmod -n 1`
             randoct3=`shuf -i 0-255 -n 1`
             echo $oct1.$randoct2.$randoct3.$x/$cidr,$gwyIP >> $tempIPfile
             let "count++"
           done;;
        0) octmod=` expr $oct1 + $addval`;
           for x in `shuf -i 1-254 -n $numips`; do   
             if [[ $count == $totalipssel ]]; then break; fi
             randoct1=`shuf -1 $oct1-$octmod -n 1`
             randoct2=`shuf -i 0-255 -n 1`
             randoct3=`shuf -i 0-255 -n 1`
             echo $randoct1.$randoct2.$randoct3.$x/$cidr,$gwyIP >> $tempIPfile
             let "count++"
           done;;
      esac
    done<$brtrfile
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
    if [[ $randomipon == 1 ]]; then
      randomIPsel=`echo $addrin | cut -d/ -f1`
    fi
    echo "auto $intnamein" >> $tempintfile
    echo "iface $intnamein inet static" >> $tempintfile
    echo "  address $addrin" >> $tempintfile
    if [[ $pass -eq 0 ]]; then
      echo "  gateway $gwyip" >> $tempintfile
      echo "  dns-nameservers $dnssrv" >> $tempintfile
    fi
    let "pass++"
  done<$tempIPfile
}

# Script execution actually starts here with a call to the MainMenu.
MainMenu

Red Team infastructure VM

Key Requirements:
  - Create Template connected to real world internet, then after installing cobaltstike run the /root/cobaltstrike/update
    - This is also stated in the PostTemplateBuild.sh script.
  - Once imported to the RGI, Set up ssh keys between this server and the a.root server.
  - Install any Malleable C2 profiles at /root/cobaltstrike/Malleable-C2-Profiles/<somefolder>/
  - Install cobaltsrike at /root/cobaltstrike
  - Make sure you copied /backbonerouters to /root/backbonerouters.  This is needed to 
    automate IP assignments based on RGI routing.
 
used for:
  -redirector using NGINX or HAProxy
  -Payload Host using Apache2 on http/https
  -CobaltStrike Teamserver
  -phishing attacks using mutt/postfix

List of scripts
	/root/scripts/buildredteam.sh    	
	 - Primary script for setting up red team servers like a redirectors, payload hosts, or CS teamserver

	/root/scripts/ManageDNS.sh		
	 - Script for assigning or deleting DNS records.  Read Automatic DNS assignment under 
	   capabilites for more info.

	/root/scripts/prepdnsbeacon.sh
	 - Script to preform an nslookup against the recursive DNS server for all newly assigned 
           DNS records.  This seems to be a necessary step in the RGI environment.

	/root/scripts/testdnsbeacon.sh
	 - Script to test cobaltstrike dns beacons.  You need to have a CS teamserver up 
	   with a DNS listener before running this.  Also need to make sure your DNS records
	   are either point to the team server or to a redirector that is redirecting to the
	   teamserver.

	/root/scripts/test-redteam-dns.sh
	 - Script will run an nslookup against all root DNS servers for all newly assigned 
	   DNS records.  If there are no errors it shouldn't output anything.

	/root/scripts/revert.sh
	 - Script will revert the server to default set up.

	/root/scripts/resetips.sh
	 - Script will reassign IP's if you have previously used the buildredteam.sh script
	 to create IPs.

	/root/scripts/phish/phish.sh
	 - Example bash script to send a phishing email with an attachment.

	/root/scripts/phish/spam.sh
	 - Example bash, essentially the same as phish.sh only it loops through a list of emails.

Capabilities
  -Automatic IP assignment.
     Uses RGI backbone router information to set IP's.  This info is in the
     /root/backbonerouters directory organzed by Country of origin folders and then 
     RGI city location files.  These files contain the routable IPs for a specific
     RGI backbone router.  Once you make your selections and set IP's the script
     will also tell you what RGI network bridge you need to connect to.
  -Automatic DNS assigment.
     The /root/ManageDNS.sh script, will take your list of IP's and SCP it over to 
     the RGI A root DNS server.  Then it run custom scripts I wrote that reside on 
     the A root server to randomly select domain names from a list of expired domains
     I grabbed from the internet and assign your IP's to them.  It will create a zone
     file for each domain and add the domain files to the /etc/bind directory, then it will
     add the zone reference to the /etc/bind/named.conf file.  Each zone file will have
     a comment on to tag it for later removal and the zone reference additions to named.conf
     will be bracketed between a //REDTEAMZONESTART and //REDTEAMZONESTOP comment lines
     to keep track of them for editing/removal later.  Then it will scp back a dnsfile.txt to 
     your root directory with the list of domain names to IPs that were assigned.
     After that it will copy the zone files and edited named.conf to all the other root 
     DNS servers, as in the B.ROOT - M.ROOT.  Each time it will restart the bind service on 
     the root servers.  When its done updating the root servers it will restart bind on the 
     recursive DNS server.  SSH-COPY-ID needs to be set up between the A.ROOT to all
     root servers and recursive DNS server for this to work.
  -Automatic Payload hosting
     It will set up an self signed Apache2 HTTPS server accessiable on both 80 and 443.
     Just place payload in /var/www/html to host payloads.
  -Cobalt Strike Teamserver 
     Script will start a cobalt Strike Teamserver, you can set the IP randomly or staticly
     select a password and a C2 profile.  Currently Mudges Malleable C2 profiles from 
     his github is on the system.  The script will walk you through selecting one.
     NOTE: if you are getting a copy of this, I've removed the License.  To make this work
     you will need to add your license.  Simple create the following file
     /root/.cobaltstrike.license     then put license key in that file.  Then connect to 
     the internet and run /root/cobaltstrike/update 
  -Phishing attacks
     For quick phishing/spamming attack capabilites the server has mutt and postfix installed.  
	 Then in /root/scripts/phish/ there are a couple of example bash scripts for sending out 
	 individual attacks or loop through a email list.
     The emaillist.txt is one for a previous exercise we've ran.

Work that still needs done.
	- Adding custom port options to the redirector build.
	- Upgrading phishing to a full featured platform like gophish for example.
	- Add support for RedELK, filebeat 6.4.1 is installed already and the log format for HAproxy 
	to support RedELK is added by the buildredteam.sh script when you make a HAProxy redirector.

HAProxy redirection
    - This script is designed to only use the "set uri" settings from a C2 profile for 
	  configuring HAProxy ACLs.  It's also set up send non-C2 traffic to www.critter.com
	  If you add your own C2 profiles, this script will still work as long as you define
	  the "set uri" in your C2 profile.  Additionally you need to put your profile in the 
	  following directory in order for the script to read it 
	      /root/cobaltstrike/Malleable-C2-Profiles/<somefolder>/<profilename>
	  for example if I added a custom C2 named facebook.profile for example I'd put it at
	      /root/cobaltstrike/Malleable-C2-Profiles/custom/facebook.profile
	  NOTE: I used a directory named "custom", however this could be anything.
	  You can change the default non-c2 traffic URL, or customize what part of the 
	  profile you want to use for the ACLs by looking at the buildredteam.sh script 
	  and modifying the BuildHAProxyConfig function.  It's pretty straightforward.

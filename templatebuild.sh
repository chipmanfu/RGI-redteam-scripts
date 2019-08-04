#!/bin/bash   
# Red team template build script
# NOTE: Prep work required.
#             VM based on OS Image: ubuntu-18.04.2-live-server-amd64.iso
#             VM Hardware settings 2GB RAM / 8 GB HD
#	   During install, accept all defaults, only add selecting OpenSSH during install.
#             Login with the user account you created during install, then
#             Sudo bash
#             Passwd to set root password
#             Then log out and log back in as root.
#             Then deluser <useryoucreate>
# Once the above is complete, copy this script to the VM, make sure the VM has internet connectivity
# then run the script.

# Grab custom scripts and config files
git clone https://github.com/chipmanfu/RGI-redteam-scripts
mv RGI-redteam-scripts/* /root/
rm -r RGI-redteam-scripts
rm -r /root/LICENSE

#Remove default unneeded services
apt-get --purge remove cloud-* -y
apt-get --purge remove unattended-upgrades -y
apt-get --purge remove open-iscsi -y
apt autoremove -y

# Install required applications
apt-get install figlet prips ipcalc traceroute ifupdown dos2unix nmap -y

#Install Phishing tools
apt-get install mutt -y
echo -e 'set edit_headers=yes\nset from="admin@live.com"\nset realname="Live Admin"' > /root/.muttrc
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
debconf-set-selections <<< "postfix postfix/mailname string localhost"

#Install NGINX for redirection
apt-get install nginx -y
systemctl stop nginx
systemctl disable nginx

#Install apache2 for payload hosting and set up a self signed default SSL cert
apt-get install apache2 -y 
subj="/C=US/ST=NewYork/L=NewYorkCity/O=foxmedia LLC"
openssl req -x509 -nodes -days 1825 -newkey rsa:2048 -keyout /etc/ssl/private/ssl-server.key -out /etc/ssl/certs/ssl-server.crt -subj "$subj"
sed -i 's/ssl-cert-snakeoil.pem/ssl-server.crt/' /etc/apache2/sites-available/default-ssl.conf
sed -i 's/ssl-cert-snakeoil.key/ssl-server.key/' /etc/apache2/sites-available/default-ssl.conf
a2enmod ssl
a2enmod headers
A2ensite default-ssl
systemctl reload apache2
systemctl stop apache2
systemctl disable apache2

#install haproxy for future redirection
apt-get install haproxy -y
systemctl disable haproxy
systemctl stop haproxy

#install filebeat version 6.4.1 for future red elk support
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.4.1-amd64.deb
dpkg -i filebeat-6.4.1-amd64.deb

#install java for cobaltstrike
apt-get install openjdk-11-jdk -y
update-java-alternatives -s java-1.11.0-openjdk-amd64

# Kill systemd-resolved - this service breaks DNS redirection.
systemctl disable systemd-resolved.service
systemctl stop systemd-resolved.service
rm /etc/resolv.conf
echo -e "nameserver 17.72.153.88" > /etc/resolv.conf

# make some general environment, fix default ubuntu color scheme issues like dark blue folder lists
echo -e "colo industry" >> /root/.vimrc
echo -e "LS_COLORS=\$LS_COLORS:'di=96:'; export LS_COLORS" >> /root/.bashrc

# enable root ssh to the box
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl ssh restart

echo "Install Complete - need to add CobaltStrike"

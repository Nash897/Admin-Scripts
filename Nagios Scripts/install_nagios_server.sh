#!/bin/bash
###########################################################
#Purpose: To install Nagios server on centos 6
#Author: Nahush
#Notes: Run as a root
#Type: RPM install
#Version: 3.5.1
###########################################################


#Download the RPM packages
cd /tmp/
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
sed -i "s/mirrorlist=https/mirrorlist=http/" /etc/yum.repos.d/epel.repo

#Install the downloaded the packages
yum -y install nagios nagios-plugins-all nagios-plugins-nrpe nrpe php httpd
chkconfig httpd on && chkconfig nagios on


#Add  Server Configurations
#setup nagios user
useradd nagios
mkdir -p /etc/nagios/servers
echo "cfg_dir=/etc/nagios/servers" >> /etc/nagios/nagios.cfg
chown -R nagios. /etc/nagios


#Enable swap memory
echo "The following process is creating a reserved swap memory and will take atleast 1 min"
dd if=/dev/zero of=/swap bs=1024 count=2097152
mkswap /swap && chown root. /swap && chmod 0600 /swap && swapon /swap
echo /swap swap swap defaults 0 0 >> /etc/fstab
echo vm.swappiness = 0 >> /etc/sysctl.conf && sysctl -p

#Start Nagios
service ntpd start
service httpd start
service nagios start

#Creating a password for nagiosadmin
htpasswd -b -c /etc/nagios/passwd nagiosadmin admin123

ip=`ifconfig eth0 | grep "inet "  | awk '{print $2}' | awk -F ":" '{print $2}'`

clear

echo "############################################"
echo "Access Nagios WebUI"
echo "http://$ip:80/nagios"
echo "username: nagiosadmin"
echo "password: admin123"
echo "Enjoy!!!!"
echo "############################################"


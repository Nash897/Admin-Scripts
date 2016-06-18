#!/bin/bash
###########################################################
#Purpose: To install Nagios client on centos 6
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
yum -y install nagios nagios-plugins-all nrpe
chkconfig nrpe on
chkconfig nagios on
service ntpd start
service iptables stop
chkconfig iptables off


#Configure
echo "***************************************************************************"
echo "Enter the Nagios Server IP Address:"
read ip
sed -i "s/allowed_hosts=127.0.0.1/allowed_hosts=$ip/" /etc/nagios/nrpe.cfg

#Start the services
service nrpe start
service nagios start

clear

echo "############################################"
echo "Access Nagios WebUI"
echo "http://$ip:80/nagios"
echo "username: nagiosadmin"
echo "password: admin123"
echo "Enjoy!!!!"
echo "############################################"


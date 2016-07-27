#!/bin/bash
###########################################################
#Purpose: To Prepare Cloudera Manager Nodes
#Author: Nahush
#Notes: Run as a root
###########################################################

yum-complete-transaction
yum clean all

sync; echo 1 > /proc/sys/vm/drop_caches

# Turn off the firewall
iptables-save > /etc/sysconfig/iptables
service iptables stop
chkconfig iptables off

#Disable SeLinux
/usr/sbin/setenforce 0
sed -i.old s/SELINUX=enforcing/SELINUX=disabled/ /etc/selinux/config

#ntpd Service
yum -y install ntp
service ntpd start
chkconfig ntpd on

#swapping off
sysctl -w vm.swappiness=0
echo 0 > /proc/sys/vm/swappiness

#Disable ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

#Disable THP pages
echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled
echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag

#Setting the hostname
ip=`ifconfig eth0 | grep "inet " | awk '{print $2}' | awk -F ":" '{print $2}'`
h=`cat /etc/hosts | grep $ip | awk -F " " {'print $2'}`
hostname "$h"
sed -i "s/HOSTNAME=.*/HOSTNAME=$h/g" /etc/sysconfig/network
service network restart 

# Installing java and jdbc
yum install java-1.8.0-openjdk -y

#Mysql Java Connector
wget http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.36.tar.gz
tar -xvzf mysql-connector-java-5.1.36.tar.gz
mkdir -p /usr/share/java/
cp mysql-connector-java-5.1.36/mysql-connector-java-5.1.36-bin.jar /usr/share/java/mysql-connector-java.jar

echo "[cloudera-manager]
name = Cloudera Manager, Version 5.7.0
baseurl = http://archive.cloudera.com/cm5/redhat/6/x86_64/cm/5.7.0/
gpgkey = http://archive.cloudera.com/redhat/cdh/RPM-GPG-KEY-cloudera
gpgcheck = 1" > /etc/yum.repos.d/cm.repo

#yum -y install cloudera-manager-daemons cloudera-manager-agent

yum-complete-transaction
yum clean all

clear
echo "Done."
#!/bin/bash
###########################################################
#Purpose: To Prepare Cloudera Manager Server, Cloudera Manager Nodes and the SQL DB
#Author: Nahush
#Notes: Run as a root
###########################################################

yum-complete-transaction
yum clean all

sync; echo 1 > /proc/sys/vm/drop_caches

echo "Enter the common root password for your nodes:"
read z

echo "Enter the IP address for the mysql database:"
read m

#distribute the passwordless keys to all the nodes
ssh-keygen -t rsa

yum -y install expect

for x in `cat /etc/hosts | awk -F " " {'print $1'} | xargs`;
do
expect -c "
   set timeout 1
   spawn ssh-copy-id root@$x
   expect yes/no { send yes\r ; exp_continue }
   expect password: { send $z\r }
   expect 100%
   sleep 1
   exit
";done
 
#send the scripts to all the nodes
#scp pre-req script/hosts/db file file to all nodes and run them ..
for x in `cat /etc/hosts | awk -F " " {'print $1'} | xargs`; do scp /etc/hosts root@$x:/etc/hosts; done
for x in `cat /etc/hosts | awk -F " " {'print $1'} | xargs`; do scp /root/pre.sh root@$x:/root/pre.sh; done
scp /root/mysql.sh root@$m:/root/mysql.sh

#Run the mysql script on mysql server
ssh root@$m bash /root/mysql.sh > /root/mysql.log	

yum-complete-transaction
yum clean all

# install CM Server
echo "[cloudera-manager]
name = Cloudera Manager, Version 5.7.0
baseurl = http://archive.cloudera.com/cm5/redhat/6/x86_64/cm/5.7.0/
gpgkey = http://archive.cloudera.com/redhat/cdh/RPM-GPG-KEY-cloudera
gpgcheck = 1" > /etc/yum.repos.d/cm.repo

yum -y install cloudera-manager-server

ip=`ifconfig eth0 | grep "inet "  | awk '{print $2}' | awk -F ":" '{print $2}'`

sleep 60

#$ip is the cm ip(host)
#$m is the mysql server ip

echo "scm_password" | /usr/share/cmf/schema/scm_prepare_database.sh -h $m -P 3306 -u root -p --config-path /etc/cloudera-scm-server --scm-host $ip mysql scm scm scm_password

yum-complete-transaction
yum clean all

service cloudera-scm-server start

#RUN THE PREREQ ON ALL NODES
for x in `cat /etc/hosts | awk -F " " {'print $1'} | xargs`; do ssh root@$x bash /root/pre.sh; done

# Update the host file with mysql hostname and Ip address
echo "$m 	mysql-server.hadoop.com" >> /etc/hosts
for x in `cat /etc/hosts | awk -F " " {'print $1'} | xargs`; do scp /etc/hosts root@$x:/etc/hosts; done
  
clear

echo "############################################"
echo "Mysql DB Password : admin"
echo "The CM server takes time to start for the first time. Check Logs"
echo "Access CM WebUI at http://$ip:7180"
echo "username: admin"
echo "password: admin"
echo "Enjoy!!!!"
echo "############################################"
 
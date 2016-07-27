#!/bin/bash
###########################################################
#Purpose: To Prepare the SQL DB for Cloudera Manager
#Author: Nahush
#Notes: Run as a root
###########################################################

yum-complete-transaction
yum clean all

sync; echo 1 > /proc/sys/vm/drop_caches

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

#Mysql Java Connector
wget http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.36.tar.gz
tar -xvzf mysql-connector-java-5.1.36.tar.gz
mkdir -p /usr/share/java/
cp mysql-connector-java-5.1.36/mysql-connector-java-5.1.36-bin.jar /usr/share/java/mysql-connector-java.jar

#set the hostname
hostname "mysql-server.hadoop.com"
sed -i "s/HOSTNAME=.*/HOSTNAME=mysql-server.hadoop.com/g" /etc/sysconfig/network
service network restart

# Install Mysql
yum -y install mysql-server

####configure my.cnf
ip=`ifconfig eth0 | grep "inet " | awk '{print $2}' | awk -F ":" '{print $2}'`

chown -R mysql /var/lib/mysql
chgrp -R mysql /var/lib/mysql

echo "[mysqld]
# binding address
bind-address=$ip
  
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql
 
# With the READ-COMMITTED isolation level, the phenomenon of dirty read is avoided, 
# because any uncommitted changes is not visible to any other transaction, until the 
# change is committed.
transaction-isolation=READ-COMMITTED
 
 
# Disabling symbolic-links is recommended to prevent assorted security risks;
# to do so, uncomment this line:
# symbolic-links=0
 
key_buffer              = 16M
key_buffer_size         = 32M
max_allowed_packet      = 16M
thread_stack            = 256K
thread_cache_size       = 64
query_cache_limit       = 8M
query_cache_size        = 64M
query_cache_type        = 1
 
 
# Important: see Configuring the Databases and Setting max_connections
max_connections         = 550
 
 
# Important: log-bin should be on a disk with enough free space
# Enable binary logging. The server logs all statements that change data to the 
# binary log, which is used for backup and replication.
#log-bin=/var/lib/mysql/logs/binary/mysql_binary_log
 
 
# For MySQL version 5.1.8 or later. Comment out binlog_format for older versions.
#binlog_format = mixed
read_buffer_size = 2M
read_rnd_buffer_size = 16M
sort_buffer_size = 8M
join_buffer_size = 8M
 
 
# InnoDB settings
default-storage_engine = InnoDB
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit  = 2
innodb_log_buffer_size          = 64M
innodb_buffer_pool_size         = 4G
innodb_thread_concurrency       = 8
innodb_flush_method             = O_DIRECT
innodb_log_file_size = 512M
 
 
[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid" > /etc/my.cnf


# Start the service 
service mysqld start
/usr/bin/mysqladmin -u root password admin

yum-complete-transaction
yum clean all

#Create DB for CM

mysql -u root -p"admin" -e "create database amon DEFAULT CHARACTER SET utf8"
mysql -u root -p"admin" -e "create database rman DEFAULT CHARACTER SET utf8"
mysql -u root -p"admin" -e "create database metastore DEFAULT CHARACTER SET utf8"
mysql -u root -p"admin" -e "create database nav DEFAULT CHARACTER SET utf8"
mysql -u root -p"admin" -e "create database navms DEFAULT CHARACTER SET utf8"
mysql -u root -p"admin" -e "create database oozie"
mysql -u root -p"admin" -e "drop database scm"

mysql -u root -p"admin" -e "create user 'root'@'cm-server.hadoop.com' identified by 'scm_password'"
mysql -u root -p"admin" -e "create user 'scm'@'cm-server.hadoop.com' identified by 'scm_password'"
mysql -u root -p"admin" -e "create user 'amon'@'cm-services.hadoop.com' identified by 'amon_password'"
mysql -u root -p"admin" -e "create user 'rman'@'cm-services.hadoop.com' identified by 'rman_password'"
mysql -u root -p"admin" -e "create user 'hive'@'cm-services.hadoop.com' identified by 'hive_password'"
mysql -u root -p"admin" -e "create user 'sentry'@'cm-services.hadoop.com' identified by 'sentry_password'"
mysql -u root -p"admin" -e "create user 'nav'@'cm-services.hadoop.com' identified by 'nav_password'"		   
mysql -u root -p"admin" -e "create user 'navms'@'cm-services.hadoop.com' identified by 'navms_password'"

mysql -u root -p"admin" -e "GRANT ALL PRIVILEGES on *.* to 'root'@'cm-server.hadoop.com' with grant option"
mysql -u root -p"admin" -e "GRANT ALL PRIVILEGES on *.* to 'scm'@'cm-server.hadoop.com' with grant option"
mysql -u root -p"admin" -e "GRANT ALL PRIVILEGES on *.* to 'amon'@'cm-services.hadoop.com' with grant option"
mysql -u root -p"admin" -e "GRANT ALL PRIVILEGES on *.* to 'rman'@'cm-services.hadoop.com' with grant option"
mysql -u root -p"admin" -e "GRANT ALL PRIVILEGES on *.* to 'hive'@'cm-services.hadoop.com' with grant option"
mysql -u root -p"admin" -e "GRANT ALL PRIVILEGES on *.* to 'sentry'@'cm-services.hadoop.com' with grant option"
mysql -u root -p"admin" -e "GRANT ALL PRIVILEGES on *.* to 'nav'@'cm-services.hadoop.com' with grant option"
mysql -u root -p"admin" -e "GRANT ALL PRIVILEGES on *.* to 'navms'@'cm-services.hadoop.com' with grant option"
mysql -u root -p"admin" -e "flush privileges"

clear
echo "Done"
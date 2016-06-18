#!/bin/bash
###########################################################
#Purpose: To add Nagios host on the Main Server on centos 6
#Author: Nahush
#Notes: Enter the host's hostname and ipaddress on command line
#Type: Run the code for each host to be added
#Version: 3.5.1
###########################################################
 

# Getting the host information
echo "Enter the client_host's hostname:"
read a
echo "Enter the client_host's ip address:"
read b

#configuring
cd /etc/nagios/servers/
`touch $a.cfg`

echo "define host {
        use                     linux-server
        host_name               $a
        alias                   $a
        address                 $b
        }

define service {
        use                             generic-service
        host_name                       $a
        service_description             PING
        check_command                   check_ping!100.0,20%!500.0,60%
        }

define service {
        use                             generic-service
        host_name                       $a
        service_description             SSH
        check_command                   check_ssh
        notifications_enabled           0
        }

define service {
        use                             generic-service
        host_name                       $a
        service_description             Current Load
        check_command                   check_local_load!5.0,4.0,3.0!10.0,6.0,4.0
        }" >> $a.cfg


#Restart the Nagios Service
service nagios restart

clear
echo "Host added successfull"

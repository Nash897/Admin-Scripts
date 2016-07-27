1. create a host file in /etc/host with all the nodes IP address and Domain name 
2. CM server hostname should be cm-server.hadoop.com
3. If database for Reporting Services is required keep its domain name as cm-services.hadoop.com
4. Rest host names can be anything of your choice
5. If you are not going to use Mysql node as a part of your cluster then dont add mysql server ip in host file, the script will take care of it
6. If you want it to be a part of the cluster then the host name for mysql server should be mysql-server.hadoop.com
7. keep all the 3 scripts in /root/ location and run the cm.sh script
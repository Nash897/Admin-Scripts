#Enter the new hostname
echo "Enter the new hostname"
read a

# Turn off the firewall
sudo iptables-save > /etc/sysconfig/iptables
sudo service iptables stop
sudo chkconfig iptables off

#Disable SeLinux
sudo /usr/sbin/setenforce 0
sudo sed -i.old s/SELINUX=enforcing/SELINUX=disabled/ /etc/selinux/config

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
sudo echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled
sudo echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag

#Setting the hostname

OLD_HOSTNAME="$( hostname )"
NEW_HOSTNAME="$a"
if [ -z "$NEW_HOSTNAME" ]; then
 echo -n "Please enter new hostname: "
 read NEW_HOSTNAME < /dev/tty
fi

if [ -z "$NEW_HOSTNAME" ]; then
 echo "Error: no hostname entered. Exiting."
 exit 1
fi

echo "Changing hostname from $OLD_HOSTNAME to $NEW_HOSTNAME..."
hostname "$NEW_HOSTNAME"
sed -i "s/HOSTNAME=.*/HOSTNAME=$NEW_HOSTNAME/g" /etc/sysconfig/network

if [ -n "$( grep "$OLD_HOSTNAME" /etc/hosts )" ]; then
 sed -i "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
else
 echo -e "$( hostname -I | awk '{ print $1 }' )\t$NEW_HOSTNAME" >> /etc/hosts
fi

service network restart > /dev/null &

clear
echo "Done."
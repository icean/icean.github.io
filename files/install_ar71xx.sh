#!/bin/sh

HTTP_URL="http://10.30.7.235"

########################################### usb ###########################################
usb(){
opkg install block-mount
opkg install kmod-usb-storage
opkg install kmod-usb-storage-extras
opkg install kmod-fs-ext4
opkg install fdisk
opkg install e2fsprogs

block detect > /etc/config/fstab
/etc/init.d/fstab enable
block mount

####  mount block on web
echo "!!!!!!!!!!!!!!!!!!!!!! Attention !!!!!!!!!!!!!!!!!!!!!!"
echo "Please use fdisk to format the usb and mount the block on \"System -> Mount Points\""
}

########################################### transmission ###########################################
transmission(){
opkg install transmission-daemon    
opkg install transmission-cli 		     
opkg install transmission-web
opkg install transmission-remote
opkg install luci-app-transmission

###generate configuration and kill the process
/etc/init.d/transmission start
/etc/init.d/transmission enable

cd && transmission-daemon
sleep 2
killall transmission-daemon

### modify the configuration in /root/.config/transmission-daemon/settings.json
sed -i 's/"rpc-whitelist-enabled": true/"rpc-whitelist-enabled": false/g' /root/.config/transmission-daemon/settings.json

### crontab
cat << EOF >> /etc/crontabs/root

## transmission
0 8 * * * /etc/init.d/transmission stop && killall transmission-daemon
0 21 * * * /etc/init.d/transmission start && cd && transmission-daemon

EOF

echo "!!!!!!!!!!!!!!!!!!!!!! Attention !!!!!!!!!!!!!!!!!!!!!!"
echo "Please start the transmission-daemon later by input the command"
}

########################################### samba ###########################################
samba(){
opkg install samba36-server
opkg install luci-app-samba

### set samba root password
smbpasswd -a root

### !!!! set configuration on the web: Services -> Network Shares
### !!!! delete or disable the option : invalid users = root
echo "!!!!!!!!!!!!!!!!!!!!!! Attention !!!!!!!!!!!!!!!!!!!!!!"
echo "set configuration on the web: Services -> Network Shares"
echo "delete or disable the option : invalid users = root"
echo "after above is done, input anything to continue"
read wait

### edit the /etc/config/samba
WORKGROUP_DEF="Garlic"
GLOBAL_SMB_NAME_DEF="Garlic"
GLOBAL_SMB_DES_DEF="Garlic"
SMB_NAME_DEF="Garlic"
SMB_PATH_DEF="/mnt/download"
SMB_USER_DEF="root"

read -p "Please input the workgroup of samba:[$WORKGROUP_DEF]" WORKGROUP
WORKGROUP=${WORKGROUP:-"Garlic"}
read -p "Please input the global name of samba:[$GLOBAL_SMB_NAME_DEF]" GLOBAL_SMB_NAME
GLOBAL_SMB_NAME=${GLOBAL_SMB_NAME:-"Garlic"}
read -p "Please input the description of samba:[$GLOBAL_SMB_DES_DEF]" GLOBAL_SMB_DES
GLOBAL_SMB_DES=${GLOBAL_SMB_DES:-"Garlic"}
read -p "Please input the name of samba:[$SMB_NAME_DEF]" SMB_NAME
SMB_NAME=${SMB_NAME:-"Garlic"}
read -p "Please input the path of samba:[$SMB_PATH_DEF]" SMB_PATH
SMB_PATH=${SMB_PATH:-"/mnt/download"}
read -p "Please input the users of samba:[$SMB_USER_DEF]" SMB_USER
SMB_USER=${SMB_USER:-"root"}

cat << EOF > /etc/config/samba
config samba
	option workgroup '$WORKGROUP'
	option homes '1'
	option name '$GLOBAL_SMB_NAME'
	option description '$GLOBAL_SMB_DES'

config sambashare
	option name '$SMB_NAME'
	option path '$SMB_PATH'
	option read_only 'no'
	option guest_ok 'no'
	option create_mask '0755'
	option dir_mask '0755'
	option users '$SMB_USER'
EOF

### samba start and statup
/etc/init.d/samba restart
/etc/init.d/samba enable
}

########################################### extra tools ###########################################
extra_tools(){
opkg install ip-full
opkg install kmod-nf-nathelper-extra
opkg install vim
opkg install htop
}

########################################### across GFW ###########################################
across_GFW_S1(){
opkg install iptables-mod-nat-extra
opkg install iptables-mod-tproxy
opkg install ipset 
opkg remove dnsmasq
opkg install dnsmasq-full
opkg install coreutils-base64 curl ca-certificates
### !!!! reboot and the ipset take affect
reboot
}

across_GFW_S2(){
SS_SERVER_DEF="45.726.103.518"
SS_PORT_DEF="3181"
SS_PASSWD_DEF="Roo2ddfasdfOpwrt"

read -p "Please input the IP of shadowsocks server:[$SS_SERVER_DEF]" SS_SERVER
SS_SERVER=${SS_SERVER:-"45.726.103.518"}
read -p "Please input the port of shadowsocks server:[$SS_PORT_DEF]" SS_PORT
SS_PORT=${SS_PORT:-"3181"} 
read -p "Please input the password of the port:[$SS_PASSWD_DEF]" SS_PASSWD
SS_PASSWD=${SS_PASSWD:-"Root@Roo2ddfasdfOpwrt"} 

### edit the /etc/dnsmasq.conf
echo "conf-dir=/etc/dnsmasq.d">>/etc/dnsmasq.conf
mkdir /etc/dnsmasq.d

### get gfw2dnsmasq and generate dnsmasq configuration
mkdir -p /root/Scripts
cd /root/Scripts
wget $HTTP_URL/Scripts/gfwlist2dnsmasq.sh
chmod u+x *.sh

cd /root/Scripts/ \
&& sh gfwlist2dnsmasq.sh -p 5353 -s redir -o redir-`date "+%Y-%m-%d"`.conf \
&& rm -rf /etc/dnsmasq.d/redir-* \
&& mv redir-`date "+%Y-%m-%d"`.conf /etc/dnsmasq.d/ \
&& /etc/init.d/dnsmasq restart

### crontab
cat << EOF >> /etc/crontabs/root

## gfwlist
0 1 * * * cd /root/Scripts/ \\
&& sh gfwlist2dnsmasq.sh -p 5353 -s redir -o redir-\`date "+%Y-%m-%d"\`.conf \\
&& rm -rf /etc/dnsmasq.d/redir-* \\
&& mv redir-\`date "+%Y-%m-%d"\`.conf /etc/dnsmasq.d/ \\
&& /etc/init.d/dnsmasq restart

EOF

### install shadowsocks
### /etc/shadowsocks.json
cd /tmp
wget $HTTP_URL/opkg/shadowsocks-libev_2.4.8-2_ar71xx.ipk
opkg install shadowsocks-libev_2.4.8-2_ar71xx.ipk

mv /etc/shadowsocks.json  /etc/shadowsocks.json.bak
cat << EOF > /etc/shadowsocks.json
{
    "server": "$SS_SERVER",
    "server_port": $SS_PORT,
    "local_port": 1080,
    "password": "$SS_PASSWD",
    "timeout": 60,
    "method": "aes-256-cfb"
}
EOF

### /etc/init.d/shadowsocks 
cp /etc/init.d/shadowsocks /etc/init.d/shadowsocks.bak
cat << EOF > /etc/init.d/shadowsocks
#!/bin/sh /etc/rc.common

START=95

SERVICE_USE_PID=1
SERVICE_WRITE_PID=1
SERVICE_DAEMONIZE=1
SERVICE_PID_FILE=/var/run/shadowsocks.pid
CONFIG=/etc/shadowsocks.json

start() {
        #service_start /usr/bin/ss-local -c \$CONFIG -b 0.0.0.0
        service_start /usr/bin/ss-redir -c \$CONFIG -b 0.0.0.0 -u -f \$SERVICE_PID_FILE
        service_start /usr/bin/ss-tunnel -c \$CONFIG -b 0.0.0.0 -l 5353 -L 8.8.8.8:53 -u
}

stop() {
        #service_stop /usr/bin/ss-local
        service_stop /usr/bin/ss-redir
        service_stop /usr/bin/ss-tunnel
}
EOF

### enable and start
killall ss-local ss-tunnel ss-redir
/etc/init.d/shadowsocks enable
/etc/init.d/shadowsocks start

### ipset and redirect the dnsmasq domain list
ipset -N redir iphash
iptables -t nat -A PREROUTING -p tcp -m set --match-set redir dst -j REDIRECT --to-port 1080

### startup
sed -i '$d' /etc/rc.local
cat << EOF >> /etc/rc.local

## shadowsocks
ipset -N redir iphash
iptables -t nat -A PREROUTING -p tcp -m set --match-set redir dst -j REDIRECT --to-port 1080

exit 0
EOF
}

########################################### logs ###########################################
logs(){
LOG_PATH_DEF="/mnt/download/Logs"
MAX_FILE_SIZE_DEF="10485760"

read -p "Please input the path of logs:[$LOG_PATH_DEF]" LOG_PATH
LOG_PATH=${LOG_PATH:-"/mnt/download/Logs"}
read -p "Please input the max size of log file:[$MAX_FILE_SIZE_DEF]" MAX_FILE_SIZE
MAX_FILE_SIZE=${MAX_FILE_SIZE:-"/mnt/download/Logs"}

mkdir -p $MAX_FILE_SIZE
cd /root/Scripts
wget $HTTP_URL/Scripts/log.sh
chmod u+x *.sh
sed -i "s#/mnt/download/Logs/#$LOG_PATH#g" log.sh
sed -i "s#10485760#$MAX_FILE_SIZE#g" log.sh

logread >> $LOG_PATH/sys.log
logread -f >> $LOG_PATH/sys.log &

### startup
sed -i '$d' /etc/rc.local
cat << EOF >> /etc/rc.local

## log
logread >> $LOG_PATH/sys.log
logread -f >> $LOG_PATH/sys.log &

exit 0
EOF

### crontab
cat << EOF >> /etc/crontabs/root

## log
0 */1 * * * sh /root/Scripts/log.sh

EOF
}

########################################### ipv6 ###########################################
ipv6_relay(){
### ipv6 relay

sed -i '/ula_prefix/d' /etc/config/network
sed -i "s/option dhcpv6 'server'/option dhcpv6 'relay'/g" /etc/config/dhcp
sed -i "s/option ra 'server'/option ra 'relay'/g" /etc/config/dhcp
sed -i "/option ra/a\ \ \ \ \ \ \ \ \option ndp 'relay'" /etc/config/dhcp

cat << EOF >> /etc/config/dhcp

config dhcp 'wan6'
	option interfere 'wan'
	option ra 'relay'
	option dhcpv6 'relay'
	option ndp 'relay'
	option master '1'
EOF
	
/etc/init.d/odhcpd restart

## startup
sed -i '$d' /etc/rc.local
cat << EOF >> /etc/rc.local

## odhcpd
sleep 5
/etc/init.d/odhcpd restart

exit 0
EOF
}

### ipv6 bridge
ipv6_bridge(){
/etc/init.d/odhcpd disable
/etc/init.d/odhcpd stop

WAN_INTERFACE=`uci get network.wan.ifname`
opkg install ebtables
ebtables -t broute -A BROUTING -p ! ipv6 -j DROP -i $WAN_INTERFACE
brctl addif br-lan $WAN_INTERFACE

## startup
sed -i '$d' /etc/rc.local
cat << EOF >> /etc/rc.local

### ipv6 bridge
ebtables -t broute -A BROUTING -p ! ipv6 -j DROP -i $WAN_INTERFACE
brctl addif br-lan $WAN_INTERFACE

exit 0
EOF
}

########################################### tinc ###########################################
tinc(){
TINC_NAME_DEF="netgear"
TINC_INTERFACE_DEF="tun0"
TINC_PORT_DEF="6565"
TINC_SUBNET_DEF="192.168.3.0/24"
TINC_INTERFACE_IP_DEF="172.16.1.3"
WAN6_IP_DEF="2001:cc0:2020:3020:2ac6:8eff:fe21:8497"
WAN_IP=`uci get network.wan6.ipaddr`

read -p "Please input the name of tinc vpn:[$TINC_NAME_DEF]" TINC_NAME
TINC_NAME=${TINC_NAME:-"netgear"}
read -p "Please input the interface of tinc vpn:[$TINC_INTERFACE_DEF]" TINC_INTERFACE
TINC_INTERFACE=${TINC_INTERFACE:-"tun0"}
read -p "Please input the port of tinc vpn:[$TINC_PORT_DEF]" TINC_PORT
TINC_PORT=${TINC_PORT:-"6565"}
read -p "Please input the subnet that will be advertised of tinc vpn:[$TINC_SUBNET_DEF]" TINC_SUBNET
TINC_SUBNET=${TINC_SUBNET:-"192.168.3.0/24"}
read -p "Please input the ip of interface of tinc vpn:[$TINC_INTERFACE_IP_DEF]" TINC_INTERFACE_IP
TINC_INTERFACE_IP=${TINC_INTERFACE_IP:-"172.16.1.3"}
read -p "Please input the wan ip:[$WAN6_IP_DEF]" WAN6_IP
WAN6_IP=${WAN6_IP:-"172.16.1.3"}

opkg install tinc
cd /etc/config/
mv tinc tinc.bak

### !!!!! add the list ConnectTo $TINC_CONNECT_TO
cat << EOF >> tinc
config tinc-net tinc
        option enabled 1

        ## Daemon Configuration (cmd arguments)
        option generate_keys 1
        option key_size 2048
        option logfile /tmp/log/tinc.tinc.log
        option debug 0

        ## Server Configuration (tinc.conf)
        option AddressFamily any

        #list ConnectTo host1
	#list ConnectTo host2

        #option DirectOnly 0
        option GraphDumpFile /tmp/log/tinc.tinc.dot
        option Interface $TINC_INTERFACE
        option Name $TINC_NAME
        option PrivateKeyFile /etc/tinc/tinc/rsa_key.priv

config tinc-host $TINC_NAME
        option enabled 1
        option net tinc
        option Port $TINC_PORT
        option Subnet $TINC_SUBNET
EOF

echo "!!!!!!!!!!!!!!!!!!!!!! Attention !!!!!!!!!!!!!!!!!!!!!!"
echo "Please edit the /etc/config/tinc and edit the list \"list ConnectTo host2\""
echo "Please input anything to continue"
read wait

cat << EOF >> /etc/config/network

config interface 'tinc'
        option ifname '$TINC_INTERFACE'   
        option defaultroute '0'
        option peerdns '0'   
        option proto 'none'
EOF

### start and generate tinc/rsa_key.priv tinc/hosts/$TINC_NAME
/etc/init.d/tinc start

cd /etc/tinc/tinc

cat << EOF >> tinc-down
#!/bin/sh
ip link set \$INTERFACE down
EOF

### !!!!! edit the route items
cat << EOF >> tinc-up
#!/bin/sh
ip='$TINC_INTERFACE_IP'
ip link set \$INTERFACE up
ip addr add \$ip/24 dev \$INTERFACE
ip route add 192.168.1.0/24 dev \$INTERFACE
ip route add 192.168.2.0/24 dev \$INTERFACE
EOF

echo "!!!!!!!!!!!!!!!!!!!!!! Attention !!!!!!!!!!!!!!!!!!!!!!"
echo "Please edit the /etc/tinc/tinc/tinc-up and edit the list \"ip route\""
echo "Please input anything to continue"
read wait

chmod u+x tinc-*

### edit /etc/tinc/tinc/hosts/$TINC_NAME
sed -i "1i Port = $TINC_PORT" hosts/$TINC_NAME
sed -i "1i Subnet = $TINC_INTERFACE_IP/32" hosts/$TINC_NAME

### add route items
sed -i "1i Subnet = $TINC_SUBNET" hosts/$TINC_NAME

### add WAN ip
sed -i "1i Address = $WAN6_IP" hosts/$TINC_NAME
sed -i "1i Address = $WAN_IP" hosts/$TINC_NAME

echo "!!!!!!!!!!!!!!!!!!!!!! Attention !!!!!!!!!!!!!!!!!!!!!!"
echo "add the ConnectTo host's public key to the folder hosts"
echo "create new firewall zone tinc"
echo "add interface tun0 to the firewall zone of tinc"
echo "add the firewall items about tinc port "
echo "Please input anything to continue"
read wait
### !!!! add the ConnectTo host's public key to the folder hosts
### !!!! create new firewall zone tinc 
### !!!! add interface tun0 to the firewall zone of tinc
### !!!! add the firewall items about tinc port 

### enable and restart tinc
/etc/init.d/tinc enable
/etc/init.d/tinc restart

### startup
sed -i '$d' /etc/rc.local
cat << EOF >> /etc/rc.local

## tinc
/etc/init.d/tinc restart

exit 0
EOF
}

########################################### python ###########################################
python_install(){
DEST_DEF="/mnt/download/packages"

read -p "Please input dest of opkg :[$DEST_DEF]" DEST
DEST=${DEST:-"/mnt/download/packages"}

echo "dest usb $DEST" >> /etc/opkg.conf
mkdir -p $DEST
opkg --dest usb install python
ln -s $DEST/usr/bin/python /usr/bin/python
ln -s $DEST/usr/lib/libpython2.7.so.1.0 /usr/lib/libpython2.7.so.1.0

### !!! copy site-packages, $DEST/usr/lib/python2.7/site-packages
cd $DEST/usr/lib/python2.7/site-packages
wget $HTTP_URL/site-packages/site-packages.tar.gz
tar xvzf site-packages.tar.gz
rm -rf site-packages.tar.gz
}

########################################### hosts update ###########################################
hosts_update(){
mkdir -p /root/Scripts/hosts
cd /root/Scripts
wget $HTTP_URL/Scripts/gethosts.sh
chmod u+x *.sh
./gethosts.sh

### crontab
cat << EOF >> /etc/crontabs/root

## hosts update
0 1 */7 * * sh /root/Scripts/gethosts.sh
0 0 1 */12 * rm -rf /root/Scripts/hosts/hosts.*

EOF
}

########################################### network authentication ###########################################
### UCAS
ucas_network(){
mkdir -p /root/Scripts/ucas
cd /root/Scripts/ucas
wget $HTTP_URL/Scripts/ucas/account.txt
wget $HTTP_URL/Scripts/ucas/Login.py
wget $HTTP_URL/Scripts/ucas/Login-full.py
wget $HTTP_URL/Scripts/ucas/monitoring.sh
chmod u+x *.sh *.py

### startup
sed -i '$d' /etc/rc.local
cat << EOF >> /etc/rc.local

## ucas network authentication
sh /root/Scripts/ucas/monitoring.sh

exit 0
EOF

### crontab
cat << EOF >> /etc/crontabs/root

## connect to Internet
0,10,20,30,40,50 * * * * sh /root/Scripts/ucas/monitoring.sh
0 0 1 */1 * echo "" > /root/Scripts/ucas/network.log

EOF
}

##### ICT
ict_network(){
mkdir -p /root/Scripts/ict
cd /root/Scripts/ict
wget $HTTP_URL/Scripts/ict/auth.py
wget $HTTP_URL/Scripts/ict/monitoring.sh
chmod u+x *.sh

### startup
sed -i '$d' /etc/rc.local
cat << EOF >> /etc/rc.local

## ict network authentication
sh /root/Scripts/ict/monitoring.sh

exit 0
EOF

### crontab
cat << EOF >> /etc/crontabs/root

## connect to Internet
0,10,20,30,40,50 * * * * sh /root/Scripts/ict/monitoring.sh
0 0 1 */1 * echo "" > /root/Scripts/ict/network.log

EOF
}

step_done(){
cat /root/step | while read line
do
    #echo $line
    if [[ $line == $1 ]];then
        return 1
    fi
done
}

echo "!!! opkg updating !!!"
#rm -rf /root/step
touch /root/step
opkg update
for i in `seq 20`
do
	echo "============================================================================"
	echo "|                    OpenWRT Software Install Wizard                       |"
	echo "|  usb          :  1      transmission  :   2        samba        :   3    |"
	echo "|  extra_tools  :  4      across_GFW_S1 :   5.1      across_GFW_S2:   5.2  |"
	echo "|  logs         :  6      ipv6_relay    :   7.1      ipv6_bridge  :   7.2  |"
	echo "|  tinc         :  8      python_install:   9        hosts_update :   10   |"
	echo "|  ucas_network :  11.1   ict_network   :   11.2     QUIT         :   0    |"
	echo "============================================================================"
    echo -e "Input your choice:\c "
    read opt
    case $opt in
        "1")
            step_done "1"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                usb
                echo "1" >> /root/step
            fi
            ;;
        "2")
            step_done "2"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                transmission
                echo "2" >> /root/step
            fi
            ;;
        "3")
            step_done "3"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                samba
                echo "3" >> /root/step
            fi
            ;;
        "4")
            step_done "4"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                extra_tools
                echo "4" >> /root/step
            fi
            ;;
		"5.1")
            step_done "5.1"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                across_GFW_S1
                echo "5.1" >> /root/step
            fi
            ;;
        "5.2")
            step_done "5.2"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                across_GFW_S2
                echo "5.2" >> /root/step
            fi
            ;;
        "6")
            step_done "6"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                logs
                echo "6" >> /root/step
            fi
            ;;
        "7.1")
            step_done "7.1"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                ipv6_relay
                echo "7.1" >> /root/step
            fi
            ;;
        "7.2")
            step_done "7.2"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                ipv6_bridge
                echo "7.2" >> /root/step
            fi
            ;;
        "8")
            step_done "8"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                tinc
                echo "8" >> /root/step
            fi
            ;;
        "9")
            step_done "9"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                python_install
                echo "9" >> /root/step
            fi
            ;;
        "10")
            step_done "10"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                host_update
                echo "10" >> /root/step
            fi
            ;;
        "11.1")
            step_done "11.1"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                ucas_network
                echo "11.1" >> /root/step
            fi
            ;;
        "11.2")
            step_done "11.2"
            re=$?
            if [[ "$re" = "1" ]];then
                echo "You have run the step!"
            else
                ict_network
                echo "11.2" >> /root/step
            fi
            ;;
		"0")
			i=20
			;;
        *)
            echo "Invalid Option!"
            ;;
    esac
done     

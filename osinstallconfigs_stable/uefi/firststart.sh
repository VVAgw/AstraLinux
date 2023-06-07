#!/bin/bash
set -x

GATEWAY="192.168.50.1"
DOMAIN="security.ru"
HOSTN="comp$RANDOM"
DC="192.168.50.10"

# Установка клиента ALD Pro и ввод компьютера в домен
case $1 in
        start)
                sleep 70
                apt update
                apt dist-upgrade -y
                DEBIAN_FRONTEND=noninteractive apt-get install -q -y aldpro-client
                mkdir -p /etc/ssl/freeipa
                # изменяем hostname
                echo "$HOSTN.$DOMAIN" > /etc/hostname
                # изменяем hosts
        IFS=" "
        SH=$(tail -n 5 /etc/hosts)
cat <<EOF > /etc/hosts
127.0.0.1       localhost.localdomain   localhost
127.0.1.1       $HOSTN
EOF
                echo $SH >> /etc/hosts


#cat <<EOF >> /etc/network/interfaces 
#auto eth0
#iface eth0 inet dhcp
    #dns-nameservers $DC
    #dns-search $DOMAIN
#EOF

                echo -e "nameserver $DC\nsearch $DOMAIN" > /etc/resolv.conf
                #systemctl restart networking.service

                # comp$RANDOM - генерация имени компьютера.
                /opt/rbta/aldpro/client/bin/aldpro-client-installer -c $DOMAIN -u admin -p vvaVolkov -d $HOSTN -i -f
                systemctl disable firststart
                ;;
        stop)
                systemctl disable firststart
                ;;
        *)
                echo "$Usage: $0 {start|stop}"
                ;;
esac
reboot


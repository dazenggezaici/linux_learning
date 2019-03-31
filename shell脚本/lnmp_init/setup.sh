#!/bin/bash

# def
menu_char="Please choice a menu[1-q]"
menu_init() {
	echo -e "\033[40m"
	clear
}

# test 

# test end
[ ! -d /opt/package ]&&mkdir -p /opt/package
if [ ! -f /opt/package/lnmp_soft.tar.gz ];then
packurl=`find / -name lnmp_soft.tar.gz | sed -n '1p'`
cp $packurl /opt/package/ && echo "已找到lnmp_soft.tar.gz包并拷贝到/opt" && sleep 1
fi

[ ! -d /opt/package/lnmp_soft/ ] && tar -xf /opt/package/lnmp_soft.tar.gz -C /opt/package/ && sleep 1.5

while :
do

menu_init
echo -e "\033[31m`cat menu_index`"
echo -en "\033[32m$menu_char"
read -p ":" option

case $option in
1)
	bash install_nginx.sh;;
2)
	bash install_mariadb.sh;;
3)
	bash install_php_base.sh;;
q|quit|exit)
	echo -e "\033[0m"
	exit;;
*)
	echo -e "\033[31mThis option was not found!"
	sleep 3
	continue;;
esac

done

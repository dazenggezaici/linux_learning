#!/bin/bash
systemctl restart mariadb &> /dev/null
[ $? -eq 0 ] && echo -e "\033[31mMariaDB已安装!!!" && sleep 3 && exit
yum -y install mariadb mariadb-devel mariadb-server
[ $? -ne 0 ] && echo -e "\033[31myum源有问题!!!" && sleep 3 && exit
systemctl restart mariadb
[ $? -eq 0 ] && echo -e "\033[32mMariaDB服务已启动!"
systemctl enable mariadb
sleep 3
exit

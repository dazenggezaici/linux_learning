#!/bin/bash
systemctl restart php-fpm &> /dev/null
[ $? -eq 0 ] && echo -e "\033[31mPHP-Base环境已安装!!!" && sleep 3 && exit
yum -y install php php-mysql /opt/package/lnmp_soft/php-fpm-5.4*.rpm
[ $? -ne 0 ] && echo -e "\033[31myum源有问题!!!" && sleep 3 && exit
systemctl restart php-fpm &>/dev/null && echo -e "\033[32mPHP-FPM服务已启动!"
systemctl enable php-fpm
sleep 3
exit

#!/bin/bash
echo -e "\033[32m安装准备中......"
nginx &>/dev/null || /nginx/sbin/nginx &>/dev/null || nginx -s stop &>/dev/null || /usr/local/nginx/sbin/nginx -s reload &>/dev/null
[ $? -eq 0 ] && echo -e "\033[31mNginx已安装!!!" && sleep 3 && exit
sleep 1
[ ! -d /opt/package/nginx-1.12* ] && tar -xf /opt/package/lnmp_soft/nginx-1.12*.tar.gz -C /opt/package/
sleep 1
id nginx &> /dev/null
[ $? -ne 0 ] && useradd -s /sbin/nologin nginx
sleep 1
yum -y install gcc openssl-devel pcre-devel
[ $? -ne 0 ] && echo -e "\033[31myum源有问题!!!" && exit
sleep 0.5
cd /opt/package/nginx-1.12*/
./configure --prefix=/usr/local/nginx --user=nginx --group=nginx --with-http_ssl_module --with-stream --with-http_stub_status_module
make && make install
ln -s /usr/local/nginx/sbin/nginx /sbin/
[ $? -eq 0 ] && echo -e "\033[33mNginx服务已安装，退出脚本后在命令行输入nginx开启服务!"
cd /
sleep 5 && exit

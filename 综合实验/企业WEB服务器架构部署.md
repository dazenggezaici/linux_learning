# 企业WEB服务器架构部署

<!--author: Todd-->

## 一. TOPO规划在同级目录中的pdf



## 二.服务器基本说明

### 所有主机系统均为CentOS7.5

### 堡垒机可用密码登录，其他所有内网机仅能使用密钥登录

### 堡垒机绑定弹性公网IP用于登录控制所有主机

### 模板机是所有内网主机的镜像模板



## 三.IP规划

### 堡垒机：

#### 	jump-server：192.168.0.199

### Git服务器：

#### 	git-server：192.168.0.198

### 七层负载均衡：

#### 	VIP：192.168.0.200  # VIP绑定一个公网IP：139.9.61.120

#### 	Nproxy0[1:2]：192.168.0.20[1:2]

### WEB集群：

#### 	web0[1:4]：192.168.0.10[1:4]  # 动态页面组

#### 	web0[5:6]：192.168.0.10[5:6]  # web05,06为静态页面组

### Redis集群：

#### 	Rnode0[1:6]：192.168.0.11[1:6]

### Ceph集群：

#### 	Cnode0[1:6]：192.168.0.12[1:6]

### ELK集群：

#### 	ES0[1:5]；192.168.0.13[1:5]

#### 	136-137  # 暂未定

#### 	Kibana01：192.168.0.39

#### 	Logstash01：192.168.0.38

### 数据库集群：

#### 	HAproxy0[1:2]；192.168.0.14[1:2]

#### 	Mycat0[1:3]：192.168.0.15[1:3]

#### 	Dnode0[1:6]：192.168.0.16[1:6]

#### 	MHA-Manager01：192.168.0.170



# 四.具体部署实施

### (一) 堡垒机

```shell
mkdir -p /etc/yum.repos.d/repo_bak/
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/repo_bak/
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.myhuaweicloud.com/repo/CentOS-Base-7.repo
yum clean all
yum repolist
yum install lrzsz
yum install ansible
systemctl stop ntpd
systemctl stop postfix
yum remove postfix ntp
yum -y install chrony
vim /etc/chrony.conf
server ntp.myhuaweicloud.com iburst  # 配置为华为云的时间服务器
systemctl restart chronyd
chronyc  sources -v
```

### 备注:

#### 安装ftp
配置自定义yum源仓库，供内网主机使用



### (二) 模板机

```shell
mkdir -p /etc/yum.repos.d/repo_bak/
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/repo_bak/
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.myhuaweicloud.com/repo/CentOS-Base-7.repo
vim /etc/yum.repos.d/local.repo  # 配置指定自定义yum源地址
[local]
name=localrepo
baseurl=ftp://192.168.0.199/myyum/
enabled=1
gpgcheck=0
####文件配置####
yum clean all
yum repolist
yum install lrzsz
systemctl stop ntpd
systemctl stop postfix
yum remove postfix ntp
yum -y install chrony
vim /etc/chrony.conf
server ntp.myhuaweicloud.com iburst  # 配置为华为云的时间服务器
systemctl restart chronyd
chronyc  sources -v
```



### (三) 七层负载均衡调度器

```shell
yum -y install keepalived
vim /etc/keepalived/keepalived.conf
! Configuration File for keepalived

global_defs {
	router_id nproxy01  #nproxy02########
}
vrrp_script chk_nginx {
	script "/etc/keepalived/nginx_check.sh"
	interval 2
	weight -5
	fall 2
	rise 1
}
vrrp_instance VI_1 {
	state MASTER  #BACKUP##########
	interface eth0
	virtual_router_id 200
	priority 100  #99##########
	advert_int 1
	authentication {
		auth_type PASS
		auth_pass 6666
	}
	track_script {
		chk_nginx
	}
	virtual_ipaddress {
		192.168.0.200
	}
}
## 配置文件中#xxxx###############表示：当前配置为主负载均衡服务器的配置，而#中的xxxx为备负载均衡服务器所需要配置的配置项。
vim /etc/keepalived/nginx_check.sh
#!/bin/bash
A=`ps -C nginx --no-header |wc -l`
if [ $A -eq 0 ];then
/usr/local/nginx/sbin/nginx
sleep 2
if [ `ps -C nginx --no-header |wc -l` -eq 0 ];then
		killall keepalived
fi
fi
chmod +x /etc/keepalived/nginx_check.sh
重启keal的playbook:  # 由于经常要重启keepalived服务，所以我们在堡垒机上创建一个playbook来操作。
Ansible配置可参考(四)WEB集群中的ansible配置
vim reload-keal.yml
---
- hosts: nweb
  remote_user: root
  tasks:
  - name: reload keepalived
    service:
    state: restarted
    name: keepalived
  - shell: iptables -F
Nginx实现动静分离，这里不讲解如何安装nginx
vim /usr/local/nginx/conf/nginx.conf
http {
    upstream dynamic_websrv {
        server 192.168.0.101 weight=2 max_fails=1 fail_timeout=20;
        server 192.168.0.102 weight=2 max_fails=1 fail_timeout=20;
        server 192.168.0.103 weight=2 max_fails=1 fail_timeout=20;
        server 192.168.0.104 weight=2 max_fails=1 fail_timeout=20;
    }
    upstream static_websrv {
        server 192.168.0.105 weight=2 max_fails=1 fail_timeout=20;
        server 192.168.0.106 weight=2 max_fails=1 fail_timeout=20;
    }
    server {
        location / {
            proxy_pass http://dynamic_websrv;
            root   html;
            index  index.html index.htm;
        }
        location ~ .*.(gif|jpg|jpeg|png|bmp|swf|css|js)$ {
            proxy_pass http://static_websrv;
        }
    }
}
```



### (四) WEB集群

#### Ansible说明：

​	由于6台服务器web配置都一致，所以直接用ansible操作

​	以下命令无特殊标示时，默认在堡垒机上执行。

```shell
mkdir pl-web/
cd pl-web/
vim ansible.cfg
[defaults]
inventory = myhosts
host_key_checking = False
####文件配置####
vim myhosts
[web:children]
dweb
sweb
nweb
[dweb]
web0[1:4]
[sweb]
web0[5:6]
[nweb]
Nproxy0[1:2]
####文件配置####
vim i-web.yml
---
- hosts: web
  remote_user: root
  tasks:
    - name: install nginx,php,php-fpm,php-mysql
      yum:
        name: nginx,php,php-fpm,php-mysql
        state: latest
    - name: start service
      service:
        state: started
        name: php-fpm
        enabled: yes
####文件配置####
ansible-playbook i-web.yml
vim e-web.yml
---
- hosts: web
  remote_user: root
  tasks:
    - name: edit nginx.conf
      copy:
        src: ./nginx.conf
        dest: /usr/local/nginx/conf/nginx.conf
        owner: root
        group: root
        mode: 0644
      tags: copy
      notify: reloadnginx
    - name: copy test-page
      copy:
        src: ./test.php
        dest: /usr/local/nginx/html/test.php
        owner: nginx
        group: nginx
        mode: 0644
      tags: send-test-page
      notify: reloadphp
  handlers:
    - name: reloadnginx
      shell: /usr/local/nginx/sbin/nginx || /usr/local/nginx/sbin/nginx -s reload
    - name: reloadphp
      service:
        name: php-fpm
        state: restarted
####文件配置####
ansible-playbook e-web.yml
```



### (五) Ceph集群

#### 在堡垒机上操作：

```shell
mkdir -p /etc/yum.repos.d/repo_bak/
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/repo_bak/
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.myhuaweicloud.com/repo/CentOS-Base-7.repo
wget -O /etc/yum.repos.d/epel.repo http://mirrors.huaweicloud.com/repo/epel-7.repo
vim /etc/yum.repos.d/ceph.repo
[ceph]
name=ceph
baseurl=http://mirrors.huaweicloud.com/ceph/rpm-jewel/el7/x86_64/
gpgcheck=0
priority =1
[ceph-noarch]
name=cephnoarch
baseurl=http://mirrors.huaweicloud.com/ceph/rpm-jewel/el7/noarch/
gpgcheck=0
priority =1
[ceph-source]
name=Ceph source packages
baseurl=http://mirrors.huaweicloud.com/ceph/rpm-jewel/el7/SRPMS/
gpgcheck=0
priority=1
```

在安装之前先把node主机做基本配置
Cnode0[1:6]都配置IP+hostname的hosts，相互能免密ssh，时间同步
还需要配置内网node主机上网：  # 这里我们通过堡垒机做代理上网
在堡垒机网卡选项里源/目的检查关闭，在堡垒机内开启路由转发，这里介绍都是临时配置，关机后就失效：

```shell
echo "1" > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o eth0 -s 192.168.0.0/24 -j SNAT --to 192.168.0.199  # 配置地址转换,注:199是堡垒机的内网IP
```

在控制台-网络控制台-找到对应的内网-添加一条路由-目的地址0.0.0.0/0，下一跳就是堡垒机IP，测试：ping baidu.com
还在堡垒机上执行：  # 下面是安装

```shell
mkdir /ceph-cluster
cd /ceph-cluster
ceph-deploy new cnode01 cnode02 cnode03
ceph-deploy install cnode01 cnode02 cnode03 cnode04 cnode05 cnode06
```

#### 报错1:

安装过程如果报python-urllib3模块装不上，可能是因为本身就有安装或者是pip版本过底，只需要在执行ceph-deploy install报错后再把各个node主机上的python-urllib3模块和pip用pip install --upgrade XXX升级即可.

```shell
ceph-deploy mon create-initial
for i in cnode0{1..3}; do ssh $i "parted  /dev/vdb  mklabel  gpt;parted  /dev/vdb  mkpart primary  1M  50%;sleep 1;parted  /dev/vdb  mkpart primary  50%  100%" & done
for i in cnode0{1..3}; do ssh $i "chown ceph.ceph /dev/vdb1;chown ceph.ceph /dev/vdb2" & done
vim 70-vdb.rules
ENV{DEVNAME}=="/dev/vdb1",OWNER="ceph",GROUP="ceph"
ENV{DEVNAME}=="/dev/vdb2",OWNER="ceph",GROUP="ceph"
for i in cnode0{1..3}; do scp 70-vdb.rules $i:/etc/udev/rules.d/; done
cd /ceph-cluster/
ceph-deploy disk zap cnode01:vdc cnode01:vdd
ceph-deploy disk zap cnode02:vdc cnode02:vdd
ceph-deploy disk zap cnode03:vdc cnode03:vdd
ceph-deploy osd create cnode01:vdc:/dev/vdb1 cnode01:vdd:/dev/vdb2
ceph-deploy osd create cnode02:vdc:/dev/vdb1 cnode02:vdd:/dev/vdb2
ceph-deploy osd create cnode03:vdc:/dev/vdb1 cnode03:vdd:/dev/vdb2
```

####  报错2:

```shell
ceph -s  # 显示too few PGs per OSD (16 < min 30)
```

#### 解决方法:

```shell
ceph osd pool set rbd pg_num 128
ceph osd pool set rbd pgp_num 128
```

将配置文件和密码共享给mds和client：

```shell
ceph-deploy admin [clientIP|clientHostname]
```

配置mds文件系统：

```shell
ceph-deploy mds create cnode04 cnode05 cnode06
ceph osd pool create cephfs_data 128  # 可以再cnode4-6的任意一台执行
ceph osd pool create cephfs_metadata 128  # 可以再cnode4-6的任意一台执行
ceph fs new myfs1 cephfs_metadata cephfs_data
ceph fs ls  # 查看文件系统信息
ceph mds stat  # 查看文件系统状态
```

客户端挂载：

```shell
yum -y install ceph-common
vim /etc/fstab
192.168.0.121:6789:/ /usr/local/nginx/html/ ceph name=admin,secretfile=/etc/ceph/secret.key,noatime 0 2
# 这里把cephfs挂载到每个web服务器的网页根目录
vim /etc/ceph/secret.key
AQDI1c9c9zyyLxAAS75B4rh3hJjQXgKXPE0qYA==
# 这串密码可以用cat /etc/ceph/ceph.client.admin.keyring 查看
```



### (六) 数据库集群

说明:在部署数据库集群Dnode0[1:6]时,使用ansible批量部署.,所有Dnode节点需要相互免密

#### 在堡垒机上:

```shell
mkdir work
cd work
vim ansible.cfg
[defaults]
inventory = myhosts
host_key_checking = False
vim myhosts
[node:children]
mt
sl
[mt]
192.168.0.16[1:3]
[sl]
192.168.0.16[4:6]
[mag]
192.168.0.170
###配置文件###
ansible all -m authorized_key -a "user=root exclusive=true manage_dir=true key='$(< /root/.ssh/id_rsa.pub)'" -k  # 需要免密才需要敲这一条
for i in {161..166}; do (scp /root/mysql-5.7.17.tar 192.168.0.$i:/root/) & done  # 将mysql包发给所有主机
# 由于是本地包安装,我们直接用ssh控制node节点安装
for i in 192.168.0.{161..166}; do ssh $i 'tar -xf /root/mysql-5.7.17.tar && echo -e "\033[32m[ok]\033[0m"' & done  # 解压
for i in 192.168.0.{161..166}; do ssh $i 'yum -y localinstall /root/* && echo -e "\033[32m[ok]\033[0m"' & done  # 安装
for i in 192.168.0.{161..166}; do ssh $i 'systemctl restart mysqld && echo -e "\033[32m[ok]\033[0m"' & done  # 启动
grep root@localhost /var/log/mysqld.log | awk '{print $NF}'  # 该命令可以筛选出初始密码
mysql -uroot -p$(grep root@localhost /var/log/mysqld.log | awk '{print $NF}') --connect-expired-password -e "alter user 'root'@'localhost' identified by 'Abc123***';"  # 结合上一条shell命令就可以自动修改Mysql初始密码了,由于这条指令中有单双引号,因此在用ssh远程发送命令时会报错,这里暂时只能把这条命令复制到node节点上执行.
```

但是如果主机很多这种方法就很傻了,可以使用Python3+paramiko模块来实现批量主机操作,这里用的也是密钥登录,统一MySQL-root登录密码为Abc123***

```python
vim ssh.py  # 这个python只是实现MySQL非交互式初始化密码

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import paramiko
def ssh_com(ip, port, key, command):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, port, username='root', pkey=key)
    result = ssh.exec_command(command)
    ssh.close()
if __name__ == '__main__':
    private_key = paramiko.RSAKey.from_private_key_file('/root/.ssh/id_rsa')
    ip_net = '192.168.0.'
    port = 22
    cmd = '''mysql -uroot -p$(grep root@localhost /var/log/mysqld.log | awk '{print $NF}') --connect-expired-password -e "alter user 'root'@'localhost' identified by 'Abc123***';"'''
    for ip in range(161, 167):
        ip = ip_net + str(ip)
        ssh_com(ip, port, private_key, cmd)

python3 ssh.py
# 前提是需要安装python3和python模块paramiko
```

#### 配置主服务器和备用主服务器(Dnode0[1:3])

```shell
pwd  # 在堡垒机的ansible工作目录
/root/work  # 在ansible工作目录
scp 192.168.0.161:/etc/my.cnf .  # 将主数据库配置文件复制到当前目录下

vim my.cnf
[mysqld]
server_id={{ ansible_hostname }}  # 这里暂时不知道怎么只取主机名后的数字,所以只能先用主机名,然后通过shell脚本去修改.
log-bin=master{{ ansible_hostname }}
relay_log_purge=off
plugin-load="rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"
# 都需要同时加载主、从的半同步复制模块并启用
rpl-semi-sync-master-enabled = 1
rpl-semi-sync-slave-enabled = 1

vim e-mysql.yml
---
- hosts: mt
  remote_user: root
  tasks:
    - template:
        src: my.cnf
        dest: /etc/my.cnf

ansible-playbook e-mysql.yml  # 运行playbook
for i in {1..3}; do ssh 192.168.0.16$i "sed -i "s/Dnode0$i/$i/" /etc/my.cnf"; done
# 将mysql配置文件中的Dnode0x修改为x
for i in {1..3}; do ssh 192.168.0.16$i "systemctl restart mysqld"; done  # 重启数据库
```

#### 配置纯从库服务器(Dnode0[4:6]),与配置主库步骤类似,但配置不同

```shell
pwd  # 在堡垒机的ansible工作目录
/root/work  # 在ansible工作目录
scp 192.168.0.164:/etc/my.cnf .  # 将从数据库配置文件复制到当前目录下

vim my.cnf
[mysqld]
server_id={{ ansible_hostname }}
relay_log_purge=off
plugin-load="rpl_semi_sync_slave=semisync_slave.so"  # 加载从的半同步复制模块即可
rpl-semi-sync-slave-enabled = 1

vim e-mysql.yml
---
- hosts: sl
  remote_user: root
  tasks:
    - template:
        src: my.cnf
        dest: /etc/my.cnf

ansible-playbook e-mysql.yml  # 运行playbook
for i in {4..6}; do ssh 192.168.0.16$i "sed -i "s/Dnode0$i/$i/" /etc/my.cnf"; done
# 将mysql配置文件中的Dnode0x修改为x
for i in {4..6}; do ssh 192.168.0.16$i "systemctl restart mysqld"; done  # 重启数据库
```

#### 配置主从同步:

主库服务器Dnode01:

```shell
mysql> grant replication slave on *.* to slave@"%" identified by "Abc123***";  # 授予权限
mysql> show master status;  # 查看主库信息
```

从服务器Dnode[2:6]:

```python
# 依旧使用python来配置从的配置选项
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import paramiko
def ssh_com(ip, port, key, command):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, port, username='root', pkey=key)
    result = ssh.exec_command(command)
    ssh.close()
if __name__ == '__main__':
    private_key = paramiko.RSAKey.from_private_key_file('/root/.ssh/id_rsa')
    ip_net = '192.168.0.'
    port = 22
    cmd = '''mysql -uroot -pAbc123*** -e "change master to master_host='192.168.0.161',master_user='slave',master_password='Abc123***',master_log_file='master161.000002',master_log_pos=438;"'''
    for ip in range(162, 167):
        ip = ip_net + str(ip)
        ssh_com(ip, port, private_key, cmd)
# cmd命令解析: master_user='slave',master_password='Abc123***'都为刚刚授权的从用户,
# master_log_file='master161.000002',master_log_pos=438;" 这两项需要在主服务器中输入
# mysql> show master status;  # 查看主库信息
# 执行:
./ssh.py或者python3 ssh.py
# 将cmd修改下
cmd = '''mysql -uroot -pAbc123*** -e "start slave;"'''
# 执行:
./ssh.py或者python3 ssh.py
```

在堡垒机上验证是否同步成功

```shell
for i in 192.168.0.{162..166}; do ssh $i 'mysql -uroot -pAbc123*** -e "show slave status\G;" | awk "/Slave_.*_Running/"'; done
# 这里有5台从服务器,所以会输出5对yes才正确
# 输出参考结果:
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
```

#### 配置MHA管理主机(MHA-Manager01):

```shell
yum -y install perl*  # 由于MHA是perl语言写的,需要安装perl语言环境
cd mha-package/
tree
.
├── app1.cnf
├── master_ip_failover
├── mha4mysql-manager-0.56.tar.gz
├── mha4mysql-node-0.56-0.el6.noarch.rpm
├── perl-Config-Tiny-2.14-7.el7.noarch.rpm
├── perl-Email-Date-Format-1.002-15.el7.noarch.rpm
├── perl-Log-Dispatch-2.41-1.el7.1.noarch.rpm
├── perl-Mail-Sender-0.8.23-1.el7.noarch.rpm
├── perl-Mail-Sendmail-0.79-21.el7.art.noarch.rpm
├── perl-MIME-Lite-3.030-1.el7.noarch.rpm
├── perl-MIME-Types-1.38-2.el7.noarch.rpm
└── perl-Parallel-ForkManager-1.18-2.el7.noarch.rpm

0 directories, 12 files
yum -y install ./perl-*.rpm
yum -y install ./mha4mysql-node-0.56-0.el6.noarch.rpm
for i in 192.168.1.{161..166}; do scp ./mha4mysql-node-0.56-0.el6.noarch.rpm $i:/root; done
for i in 192.168.1.{161..166}; do ssh $i 'yum -y install /root/mha4mysql-node-0.56-0.el6.noarch.rpm'; done
tar -xf mha4mysql-manager-0.56.tar.gz
cd mha4mysql-manager-0.56/
perl Makefile.PL
make && make install
mkdir /etc/mha_manager_dir
cp ./samples/conf/app1.cnf /etc/mha_manager_dir/
vim /etc/mha_manager_dir/app1.cnf
[server default]
manager_workdir=/etc/mha_manager_dir
manager_log=/etc/mha_manager_dir/manager.log

master_ip_failover_script=/etc/mha_manager_dir/master_ip_failover  # 指定主库故障切换脚本
ssh_user=root  # 指定远程登录的用户和密码
ssh_port=22
repl_user=slave  # 指定主服务器授权给从服务器同步用的账户和密码
repl_password=Abc123***
user=todd  # 用于监控的用户，需要有所有权限且管理主机可以登录，可以是root，但root用户默认只能本地登录
password=Abc123***

[server1]
hostname=Dnode01
candidate_master=1  # 参与主库竞选

[server2]
hostname=Dnode02
candidate_master=1

[server3]
hostname=Dnode03
candidate_master=1

[server4]
hostname=Dnode04
no_master=1  # 不参与主库竞选
[server5]
hostname=Dnode05
no_master=1
[server6]
hostname=Dnode06
no_master=1
pwd
/root/mha-package
cp master_ip_failover /etc/mha_manager_dir/
chmod +x /etc/mha_manager_dir/master_ip_failover
# master_ip_failover该文件需要修改下VIP变量和给该文件赋于X权限,这里我们定VIP为192.168.0.169
```

#### 给当前主库配置VIP和授权监控用户:

```shell
ifconfig eth0:1 192.168.0.169
mysql -uroot -pAbc123*** -e 'grant all on *.* to "todd"@"%" identified by "Abc123***";'
# 配置监控用户在主库上
```

测试mha集群,在mha管理节点MHA-Manager01上执行:

```shell
masterha_check_ssh --conf=/etc/mha_manager_dir/app1.cnf  # 测试ssh连接
	All SSH connection tests passed successfully.  # 成功提示
masterha_check_repl --conf=/etc/mha_manager_dir/app1.cnf  # 测试主从同步
	MySQL Replication Health is OK.  # 成功提示
# 上面步骤一般都会报错,只需要看报错信息排错即可.
masterha_manager --conf=/etc/mha_manager_dir/app1.cnf  # 启动服务后会占用一个终端,需要开多一个终端验证
masterha_check_status --conf=/etc/mha_manager_dir/app1.cnf  # 查看服务状态
	app1 (pid:20524) is running(0:PING_OK), master:Dnode01
```

#### 测试高可用:

```shell
# 先把主库Dnode01的mysql服务停用:
systemctl stop mysqld
# 然后mha进程会结束
# 将mha指令按下方格式再启动
masterha_manager --conf=/etc/mha_manager_dir/app1.cnf --remove_dead_master_conf --ignore_last_failover
masterha_check_status --conf=/etc/mha_manager_dir/app1.cnf  # 查看服务状态
	app1 (pid:20524) is running(0:PING_OK), master:Dnode02
```






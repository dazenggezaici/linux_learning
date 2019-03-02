一、红帽考试及环境介绍
1. RHCSA（红帽认证系统管理员）
    全机试，时长150分钟
    约16道题，满分300分（210分合格）
2. RHCE（红帽认证工程师）
    全机试，时长210分钟
    约22道题，满分300分（210分合格）
3. 考试环境说明（X为考生编号）
    !!每名考生一台真实机，这台真机上提供虚拟机，答题全部在虚拟机中完成
    !!桌面上会提供访问考试平台及虚拟机的快捷方式
    !!由考官服务器提供所需软件、DNS/DHCP/集中认证等必要的资源
    !!真实机： foundation.domainX.example.com
    !!虚拟机-RHCSA部分：station.domainX.example.com
    !!虚拟机-RHCE部分：system1.domainX.example.com、system2.domainX.example.com


二、练习环境说明
1. 每人可使用3台虚拟机
    !!虚拟机 classroom，相当于考官服务器：classroom.example.com
    !!虚拟机 server，相当于答题机1：server0.example.com 
    !!虚拟机 desktop，相当于答题机2：desktop0.example.com
3. 快速重置练习环境
    !! 按顺序执行，根据提示输入 y 确认
    [root@room9pc13 ~]# rht-vmctl  reset  classroom
    [root@room9pc13 ~]# rht-vmctl  reset  server
    [root@room9pc13 ~]# rht-vmctl  reset  desktop

    rht-vmctl 脚本控制参数说明：
    rht-vmctl  reset  虚拟机名 		【断电-还原-开启虚拟机】
    rht-vmctl  poweroff  虚拟机名 	【强制关闭虚拟机】
    rht-vmctl  start  虚拟机名		【开启虚拟机】

#!/bin/bash
# def
virpwd='/var/lib/libvirt/images/'
dmqcow="${virpwd}node.qcow2"
dmxml="${virpwd}demo.xml"
echo "请输入一个数值用于标示"
read -p "number:" num

# create
cp ${dmxml} /etc/libvirt/qemu/mynode$num.xml
qemu-img create -b ${dmqcow} -f qcow2 ${virpwd}mynode$num.img 50G
sed -i "s/<name>centos7.0<\/name>/<name>mynode$num<\/name>/" /etc/libvirt/qemu/mynode$num.xml
sed -i "s/mynode.qcow2/mynode$num.img/" /etc/libvirt/qemu/mynode$num.xml
# start
virsh define /etc/libvirt/qemu/mynode$num.xml

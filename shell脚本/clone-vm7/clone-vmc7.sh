#!/bin/bash
# def
virpwd='/var/lib/libvirt/images/'
dmqcow="${virpwd}node.qcow2"
dmxml="${virpwd}demo.xml"
name='Z'
echo "请输入一个数值用于标示"
read -p "number:" num

# create
cp ${dmxml} /etc/libvirt/qemu/${name}${num}.xml
qemu-img create -b ${dmqcow} -f qcow2 ${virpwd}${name}${num}.img 50G
sed -i "s/<name>centos7.0<\/name>/<name>${name}${num}<\/name>/" /etc/libvirt/qemu/${name}${num}.xml
sed -i "s/mynode.qcow2/${name}${num}.img/" /etc/libvirt/qemu/${name}${num}.xml
# start
virsh define /etc/libvirt/qemu/${name}${num}.xml

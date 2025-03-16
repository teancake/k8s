装好系统之后需要做的

```
pacman -S openssh  sudo
systemctl start sshd
systemctl enable sshd
useradd -m -G wheel reprise
passwd reprise
vim /etc/sudoers

```
之后一定要测试一下ssh是否连得上

```
iwctl --passphrase pdf station wlan0 connect-hidden sake

sudo pacman -S qemu-base libvirt dnsmasq iptables-nft bridge-utils openbsd-netcat libguestfs guestfs-tools virt-install


sudo usermod -aG libvirt $(id -un)
sudo usermod -aG kvm $(id -un)
sudo usermod -aG libvirt-qemu $(id -un)
```


```vim /etc/polkit-1/rules.d/50-libvirt.rules```

```
/* Allow users in mykvm group to manage the libvirt
daemon without authentication */
polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" &&
        subject.isInGroup("kvm")) {
            return polkit.Result.YES;
    }
});

```

```
cat <<EOF | sudo tee /etc/modules-load.d/modules.conf
virtio-net
virtio-blk
virtio-scsi
virtio-balloon
EOF

```

设置网桥，IP地址和有线网卡名称看情况改
```
cat <<EOF | sudo tee /etc/systemd/network/br-kvm.netdev
[NetDev]
Name=br-kvm
Kind=bridge
EOF


cat <<EOF | sudo tee /etc/systemd/network/br-kvm.network
[Match]
Name=br-kvm

[Network]
Address=192.168.50.16/24
Gateway=192.168.50.1
EOF


cat <<EOF | sudo tee /etc/systemd/network/enp44s0.network
[Match]
Name=enp44s0

[Network]
Bridge=br-kvm
EOF
```
关闭网卡的tcp segmentation offload功能，offload可能会导致网卡hang

```bash
cat << EOF | sudo tee /etc/systemd/network/01-disable-tso.link
[Match]
OriginalName=enp44s0


[Link]
TCPSegmentationOffload=false
TCP6SegmentationOffload=false
EOF
```
之后重启systemd-networkd服务，并通过ethtool查看tso是否已经关闭，命令如下
```bash
sudo systemctl reload systemd-networkd
sudo systemctl restart systemd-networkd
sudo pacman -S ethtool
sudo ethtool --show-features enp44s0 | grep tcp
```



```
echo "allow all" | sudo tee /etc/qemu/${USER}.conf

echo "include /etc/qemu/${USER}.conf" | sudo tee --append /etc/qemu/bridge.conf 

sudo chown root:${USER} /etc/qemu/${USER}.conf

sudo chmod 640 /etc/qemu/${USER}.conf

sudo systemctl enable systemd-networkd
sudo systemctl start systemd-networkd
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

之后安装K8S




# 安装k8s
可以参考 https://wiki.archlinux.org/title/KVM 来做虚拟机之前的准备，比如一些必须的内核模块的加载。

## 设置网桥 

网桥可以让宿主机和所有的虚拟机在一个网络里，如果不想这样，可以用NAT的方式

下面这段代码不再用了，用它装出来的网桥系统重启之后就丢了（`add_bridge.sh`）。 可以用systemd-networkd的配置文件来做一个。 networkd的配置文件在networkd_conf里。

```bash
IP_ADDR=192.168.50.200/24
BRIDGE_NAME=br-kvm
ETH_DEV=enp44s0
GATEWAY=192.168.50.1
sudo ip link add name $BRIDGE_NAME type bridge
sudo ip link set dev $BRIDGE_NAME up
sudo ip address add $IP_ADDR dev $BRIDGE_NAME
sudo ip route append default via $GATEWAY dev $BRIDGE_NAME
sudo ip link set $ETH_DEV master $BRIDGE_NAME
sudo ip address del $IP_ADDR dev $ETH_DEV
```
系统重启之后网桥需要重建。 

## kvm 虚拟机
### ubuntu cloud image
比如22.04的地址是 https://cloud-images.ubuntu.com/jammy/current/

```bash
trap "echo interrupted, script exit; exit" INT
NODE_NAME=kube-worker-lindor
IMAGE_PATH=/var/kvm/$NODE_NAME.img
echo "create kvm domain "$NODE_NAME
read -p "is this what you want? [Ny]" confirm
echo $confirm
if [[ $confirm != "y" ]]; then echo "stopped."; exit ; fi

echo "copy image file"
sudo mkdir -p /var/kvm
sudo cp ~/jammy-server-cloudimg-amd64-disk-kvm.img $IMAGE_PATH
sudo chown libvirt-qemu:libvirt-qemu $IMAGE_PATH
sudo chmod 660 $IMAGE_PATH
echo "image file copied, ready to start the vm"
sudo virt-install  \
    --virt-type=kvm  \
    --name $NODE_NAME  \
    --memory 30000  \
    --vcpus=10,maxvcpus=10  \
    --osinfo generic \
    --disk path=$IMAGE_PATH \
    --import \
    --nographics  \
    --network bridge=br-kvm,model=virtio  \
    --console pty,target_type=virtio \
    --debug

sudo virsh stop $NODE_NAME && while [ "$(sudo virsh domstate $NODE_NAME)" != "shut off" ]; do echo "wait domain shutdown" sleep 5; done && echo "Domain has shut down." && qemu-img resize $IMAGE_PATH 350G && sudo virsh setmaxmem $NODE_NAME 36G
sudo virsh start $NODE_NAME && sudo virsh setmem $NODE_NAME 36G
sudo virsh autostart $NODE_NAME
```

### centos7
可以直接用现成的cloudimage，比如centos 7的地址是
https://cloud.centos.org/centos/7/images/

cloudimage的root密码是随机生成的，并且没有创建用户，所以没有办法登录，可以用virt-sysprep命令改一下root密码，之后就可以用这个镜像来启动虚拟机了 (`virtinstall_centos_worker.sh`) 

```bash
sudo virt-sysprep -a CentOS-7-x86_64-GenericCloud-2003.qcow2 --root-password password:super 
```

```bash
trap "echo interrupted, script exit; exit" INT
NODE_NAME=kube-worker-cen0
IMAGE_PATH=/var/kvm/$NODE_NAME.qcow2
echo "create kvm domain "$NODE_NAME
read -p "is this what you want? [Ny]" confirm
echo $confirm
if [[ $confirm != "y" ]]; then echo "stopped."; exit ; fi

echo "copy image file"
sudo mkdir -p /var/kvm
sudo cp ~/CentOS-7-x86_64-GenericCloud.qcow2 $IMAGE_PATH
sudo chown libvirt-qemu:libvirt-qemu $IMAGE_PATH
sudo chmod 660 $IMAGE_PATH
echo "image file copied, ready to start the vm"
sudo virt-install  \
    --virt-type=kvm  \
    --name $NODE_NAME  \
    --memory 2048  \
    --vcpus=2,maxvcpus=2  \
    --os-variant=centos7 \
    --disk path=$IMAGE_PATH \
    --import \
    --nographics  \
    --network bridge=br-kvm,model=virtio  \
    --console pty,target_type=virtio \
    --debug 
```
注意virt-install一定要sudo，我也不知道为啥，不用sudo装的虚拟机不会自动启动，autostart不管用。


虚拟机启动之后，可以用root密码登录，之后都在root下操作即可

需要注意的是，有的镜像默认磁盘大小比较小，比如centos7的只有8G，很容易磁盘空间不够，可以通过一下方式扩容：
1. 虚拟机镜像文件扩容`qemu-img resize kube-worker-cen0.qcow2 30G`，扩容前需要虚拟机关掉。
2. 虚拟机磁盘扩容，需要登录到虚拟机上，可以用lsblk看磁盘空间，使用fdisk把目前的分区删掉，再新建一个分区。`sudo fdisk /dev/vda`，之后d, n, w 就行，这步很危险，确保你知道自己在干啥。
3. 重启系统，xfs文件系统扩容 `sudo xfs_growfs -d /dev/vda1`

## 安装K8s
### ubuntu cloud image
#### 磁盘空间
ubuntu cloud image磁盘默认大小只有2G，需要先进行扩容
```bash
lsblk
sudo growpart /dev/sda 1 && sudo resize2fs /dev/sda1
lsblk
df -h
```

#### 网络 
不知道为什么，ubuntu cloud image默认网络没有配置好, sshd服务也是挂的，可以通过以下命令配置
```bash
cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens2:
      dhcp4: yes
EOF

chmod 600 /etc/netplan/01-netcfg.yaml && netplan apply

sudo ssh-keygen -A
sudo systemctl restart sshd.service
```
之后可以通过`ip addr`查看网络状态。如果允许ssh通过密码登录，可以执行
```bash 
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
sudo systemctl restart sshd.service
```



### centos 7
**注意，在2024年7月以后，Centos 7的官方源已停止服务，如果要继续使用centos7的话，需要先修改源为vault的地址，之后再执行下面的脚本。**
首先使用`cat /etc/centos-release`查看centos的版本，之后可以在清华的源页面找到修改方法。 https://mirrors.tuna.tsinghua.edu.cn/help/centos-vault/ 

master节点和worker节点的安装命令完全一致（`root_script.sh`）
**注意下面的代码在worker节点上执行, sudo virsh 之后，console 到worker虚拟机上运行，一定不要在宿主机上运行。**
```bash
NODE_NAME=kube-worker1
echo "node host name is " $NODE_NAME
echo "add using sissy with password sissy"
adduser sissy
echo "sissy" | passwd --stdin sissy
usermod -aG wheel sissy
echo "%wheel  ALL=(ALL)       ALL" >> /etc/sudoers
yum install -y vim

echo "install docker"
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

yum install -y docker-ce-20.10.17 docker-ce-cli-20.10.17


mkdir -p /etc/docker
touch /etc/docker/daemon.json
cat <<EOF > /etc/docker/daemon.json 
{
"registry-mirrors": ["https://dockerproxy.com", "https://docker.mirrors.ustc.edu.cn"],
"exec-opts": ["native.cgroupdriver=systemd"]
}
EOF


mv /etc/containerd/config.toml /etc/containerd/config.toml.bak
containerd config default > /etc/containerd/config.toml
sed -i 's/registry.k8s.io\/pause:3.6/registry.aliyuncs.com\/google_containers\/pause:3.9/' /etc/containerd/config.toml

systemctl start docker
systemctl enable docker
systemctl status docker

echo "install kubelet, kubeadm and kubectl"

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum install -y kubelet kubeadm kubectl
yum check-update
yum install -y yum-utils device-mapper-persistent-data lvm2


echo "Update Iptables Settings"
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

echo "Disable SELinux"
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
cat /etc/selinux/config 

echo "Disable SWAP"
cat /etc/fstab 
sed -i '/swap/d' /etc/fstab
swapoff -a

systemctl enable kubelet
systemctl start kubelet
hostnamectl set-hostname $NODE_NAME 

# install NTP daemon, so that all nodes have the same time. Weird thing may happen if nodes are out of sync (e.g. airflow tasks stop running if time of workers drift too large.)
yum install ntp -y
systemctl start ntpd
systemctl enable ntpd

echo "check files"
cat /etc/sysctl.d/k8s.conf
cat /etc/selinux/config
cat /etc/fstab
cat /etc/docker/daemon.json

```

### 启动master节点 
```bash
kubeadm init --image-repository registry.aliyuncs.com/google_containers --pod-network-cidr=10.244.0.0/16
```
启动master节点，master节点还需要安装flannel网络插件，如果虚拟机访问不了github，可以先下载下来，再本地安装。
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

之后就可以退出root，用普通用户登录，然后执行
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config 
```
可以通过下面命令来查看节点状态 
```bash
kubectl get nodes 
kubectl get pods --all-namespaces 
kubectl describe pod kube-proxy-k7fdz -n kube-system 
```

如果需要重来，切回root, 执行
```bash
kubeadm reset
```

可以用```docker info```来查看docker的配置，如果普通用户木有权限，可以执行下面的命令，然后重新登录一下就行。

```bash
sudo usermod -aG docker `id -un`
```

### 启动worker节点 
在k8s的主节点执行下面的命令，可以得到加入worker节点的命令 
```
kubeadm token create --print-join-command 
```
之后在要加入的worker节点上执行即可，命令大概长下面的样子。
```bash
kubeadm join 192.168.50.246:6443 --token j3hnr7.xx7xthtkdmm2c4it --discovery-token-ca-cert-hash sha256:2833dc1983fecb53f23629ccce63f0cf34591f0ddbc0885a4c8ff216f74d39ed
```

参考 [CentOS7 部署K8S集群
](https://luckymrwang.github.io/2021/04/25/CentOS7-%E9%83%A8%E7%BD%B2K8S%E9%9B%86%E7%BE%A4/) 

NODE_NAME=kube-worker0
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


# check files
echo "check files"
cat /etc/sysctl.d/k8s.conf
cat /etc/selinux/config
cat /etc/fstab
cat /etc/docker/daemon.json

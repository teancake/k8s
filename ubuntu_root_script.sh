NODE_NAME=kube-worker-mark
echo "node host name is " $NODE_NAME
echo "add using sissy with password sissy"
adduser sissy
echo "sissy:sissy" | chpasswd

usermod -aG sudo sissy

echo "install docker"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |   tee /etc/apt/sources.list.d/docker.list


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/kubernetes/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list > /dev/null


apt-get update && apt install -y docker-ce


mkdir -p /etc/docker
touch /etc/docker/daemon.json
cat <<EOF > /etc/docker/daemon.json 
{
"registry-mirrors": ["https://dockerproxy.com", "https://docker.mirrors.ustc.edu.cn"],
"exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

mv /etc/containerd/config.toml /etc/containerd/config.toml.bak
containerd config default > /etc/containerd/config.toml && sed -i 's/registry.k8s.io\/pause:3../registry.aliyuncs.com\/google_containers\/pause:3.9/' /etc/containerd/config.toml && sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

cat <<EOF >> /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

systemctl daemon-reload
systemctl restart containerd

systemctl start docker
systemctl enable docker


echo "install kubelet, kubeadm and kubectl"
apt-get update
apt-get install -y kubelet kubeadm kubectl



echo "Update Iptables Settings"
sudo modprobe br_netfilter

cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system


echo "Disable SWAP"
cat /etc/fstab 
sed -i '/swap/d' /etc/fstab
swapoff -a

systemctl enable kubelet
systemctl start kubelet
hostnamectl set-hostname $NODE_NAME 

echo "check files"
cat /etc/sysctl.d/k8s.conf
cat /etc/fstab
cat /etc/docker/daemon.json

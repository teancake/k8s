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

trap "echo interrupted, script exit; exit" INT
NODE_NAME=kube-worker-mark
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

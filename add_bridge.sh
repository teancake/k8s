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

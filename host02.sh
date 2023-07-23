# Start the VM2/HOST2, update the repository
sudo apt update

# Install essential tools
sudo apt -y install net-tools docker.io openvswitch-switch

# Step-01
# Create two bridge using ovs
sudo ovs-vsctl add-br ovs-br0
sudo ovs-vsctl add-br ovs-br1

# add port/interfaces to bridges
sudo ovs-vsctl add-port ovs-br0 veth0 -- set interface veth0 type=internal
sudo ovs-vsctl add-port ovs-br1 veth1 -- set interface veth1 type=internal

# check the status of bridges
sudo ovs-vsctl show

# set the ip to the created port/interfaces
sudo ip address add 192.168.50.1/24 dev veth0 
sudo ip address add 192.168.60.1/24 dev veth1 
ip a

# up the interfaces and check status
sudo ip link set dev veth0 up
sudo ip link set dev veth1 up
ip a

# Step-02

# create a docker image from the docker file 
sudo docker build . -t ubuntu-docker

# create containers from the created image; Containers not connected to any network
sudo docker run -d --net=none --name docker3 ubuntu-docker
sudo docker run -d --net=none --name docker4 ubuntu-docker

# check container status and ip 
sudo docker ps
sudo docker exec docker3 ip a
sudo docker exec docker4 ip a

# add ip address to the container using ovs-docker utility 
sudo ovs-docker add-port ovs-br0 eth0 docker3 --ipaddress=192.168.50.12/24 --gateway=192.168.50.1
sudo docker exec docker3 ip a

sudo ovs-docker add-port ovs-br1 eth0 docker4 --ipaddress=192.168.60.12/24 --gateway=192.168.60.1
sudo docker exec docker4 ip a

# ping the gateway to check if container connected to ovs-bridges
sudo docker exec docker3 ping 192.168.50.1
sudo docker exec docker4 ping 192.168.60.1


# Step-03
# one thing to check; as vxlan communicate using udp port 4789, check the current status
netstat -ntulp

# Create the vxlan tunnel using ovs vxlan feature for both bridges to another hosts bridges
# make sure remote IP and key options; they are important
sudo ovs-vsctl add-port ovs-br0 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=192.168.100.190 options:key=1000 options:dst_port=4799
sudo ovs-vsctl add-port ovs-br1 vxlan1 -- set interface vxlan1 type=vxlan options:remote_ip=192.168.100.190 options:key=2000 options:dst_port=4799

# check the port again; it should be listening
netstat -ntulp | grep 4799

sudo ovs-vsctl show

ip a


# It's time to check the connectivity

# FROM docker3
# will get ping
sudo docker exec docker3 ping 192.168.50.12 #Local IP
sudo docker exec docker3 ping 192.168.50.11 #Remote Host IP


# will be failed due to diffrent Tunnel by Diffrent VNI
sudo docker exec docker3 ping 192.168.60.11
sudo docker exec docker3 ping 192.168.60.12

# FROM docker4
# will get ping
sudo docker exec docker4 ping 192.168.60.12 #Local IP
sudo docker exec docker4 ping 192.168.60.11 #Remote Host IP


# will be failed due to diffrent Tunnel by Diffrent VNI
sudo docker exec docker4 ping 192.168.50.11
sudo docker exec docker4 ping 192.168.50.12


# NAT Conncetivity for recahing the internet

sudo cat /proc/sys/net/ipv4/ip_forward

# enabling ip forwarding by change value 0 to 1
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -p /etc/sysctl.conf
sudo cat /proc/sys/net/ipv4/ip_forward

sudo iptables -t nat -L -n -v


sudo iptables --append FORWARD --in-interface veth1 --jump ACCEPT
sudo iptables --append FORWARD --out-interface veth1 --jump ACCEPT
sudo iptables --table nat --append POSTROUTING --source 192.168.60.0/24 --jump MASQUERADE
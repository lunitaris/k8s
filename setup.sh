#!/bin/bash  
# Script: Install kubectl, kubelet (and kubeadm on master node only)
# copy this script and run in all master and worker nodes  
#i1) Switch to root user [ sudo -i]  

typeNode="N"
read -p "Master Node? (y/N)" typeNode

##############################################################################################
#2) Disable swap & add kernel settings  
  
swapoff -a  
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab  

##############################################################################################
#3) Add kernel settings & Enable IP tables(CNI Prerequisites)  
  
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf  
overlay  
br_netfilter  
EOF


modprobe overlay  
modprobe br_netfilter  
  
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1  
net.bridge.bridge-nf-call-ip6tables = 1  
net.ipv4.ip_forward = 1
EOF

sysctl --system  

##############################################################################################
#4) Install containerd run time  

apt-get update -y  
apt-get install ca-certificates curl gnupg lsb-release -y  
  
#Note: We are not installing Docker Here.Since containerd.io package is part of docker apt repositories hence we added docker repository & it's key to download and install containerd.  
# Add Docker’s official GPG key:  
sudo mkdir -p /etc/apt/keyrings  
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg  
  
#Use follwing command to set up the repository:  
  
echo \  
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \  
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null  
##############################################################################################  
# Install containerd  
  
apt-get update -y  
apt-get install containerd.io -y  
  
# Generate default configuration file for containerd  
  
#Note: Containerd uses a configuration file located in /etc/containerd/config.toml for specifying daemon level options.  
#The default configuration can be generated via below command.  
containerd config default > /etc/containerd/config.toml  

# Run following command to update configure cgroup as systemd for contianerd.  
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml  
  
# Restart and enable containerd service  
systemctl restart containerd  
systemctl enable containerd  

##############################################################################################
#5) Installing kubeadm, kubelet and kubectl
# Update the apt package index and install packages needed to use the Kubernetes apt repository:  
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg

# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly

##############################################################################################
# Update apt package index, install kubelet, kubeadm and kubectl, and pin their version:  
apt-get update
apt-get install -y kubelet

if [[ "$typeNode" == "y" ]]; then
        apt install kubeadm kubectl -y
fi

# apt-mark hold will prevent the package from being automatically upgraded or removed.  
apt-mark hold kubelet kubeadm kubectl  
  
# Enable and start kubelet service  
systemctl daemon-reload  
systemctl start kubelet  
systemctl enable kubelet.service

sleep 5
##############################################################################################
#### IF MASTER NODE, INSTALL kubeadm, kubectl and Initialize the cluster
if [[ "$typeNode" == "y" ]]; then
        kubeadm init
fi

exit 0

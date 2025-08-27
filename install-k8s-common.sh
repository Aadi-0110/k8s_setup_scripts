#!/usr/bin/env bash
# install-k8s-common.sh
# Purpose: base OS tweaks + k8s binaries + pick cluster NIC
set -euo pipefail

echo "=== Kubernetes prerequisite installation ==="
read -rp "Enter the NIC to carry cluster traffic (e.g. eno1): " K8S_IFACE
K8S_IP=$(ip -4 addr show "$K8S_IFACE" | awk '/inet /{print $2}' | cut -d/ -f1)

if [[ -z "$K8S_IP" ]]; then
  echo "ERROR: No IPv4 address found on $K8S_IFACE"; exit 1; fi
echo "Using $K8S_IFACE ➜ $K8S_IP"

# --- Packages ------------------------------------------------------------
sudo apt update && sudo apt -y upgrade
sudo apt -y install apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key |
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" |
  sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt -y install kubelet kubeadm kubectl containerd
sudo apt-mark hold kubelet kubeadm kubectl

# --- containerd ----------------------------------------------------------
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml
sudo systemctl restart containerd && sudo systemctl enable containerd

# --- swap off & kernel settings -----------------------------------------
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/' /etc/fstab
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay; sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# --- force kubelet to register $K8S_IP (—node-ip)[60] --------------------
sudo mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/20-nodeip.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--node-ip=${K8S_IP}"
EOF
sudo systemctl daemon-reload && sudo systemctl enable kubelet

# --- persist the choice for later scripts --------------------------------
sudo mkdir -p /etc/k8s-iface
echo "$K8S_IFACE" | sudo tee  /etc/k8s-iface/nic
echo "$K8S_IP"   | sudo tee  /etc/k8s-iface/ip

echo "=== Base installation complete on $(hostname) ==="

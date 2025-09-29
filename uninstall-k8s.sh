#!/usr/bin/env bash
# uninstall-k8s.sh
# Purpose: Completely remove Kubernetes and related components from a node.

set -euo pipefail

echo "🛑 This script will PERMANENTLY remove Kubernetes, containerd, and all associated configuration."
read -rp "   Are you sure you want to continue? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

echo "▶️ Draining node and resetting kubeadm..."
# The reset might fail if the node is already offline, so we ignore errors.
sudo kubeadm reset -f || true

echo "▶️ Stopping and disabling services..."
sudo systemctl disable --now kubelet || true
sudo systemctl disable --now containerd || true

echo "▶️ Purging Kubernetes and containerd packages..."
sudo apt-mark unhold kubelet kubeadm kubectl
sudo apt-get purge -y kubelet kubeadm kubectl containerd*
sudo apt-get autoremove -y

echo "▶️ Removing repository configurations..."
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes.gpg
sudo apt-get update

echo "▶️ Deleting all cluster and component data..."
sudo rm -rf /etc/cni/net.d
sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/containerd
sudo rm -rf /etc/containerd

# Cleanup specific to the setup scripts
sudo rm -rf /etc/k8s-iface
sudo rm -f /etc/systemd/system/kubelet.service.d/20-nodeip.conf

echo "▶️ Reverting OS changes..."
sudo rm -f /etc/modules-load.d/k8s.conf
sudo rm -f /etc/sysctl.d/k8s.conf
# Re-enable swap by uncommenting the line in fstab
# sudo sed -i '/ swap / s/^#//' /etc/fstab

sudo systemctl daemon-reload

echo "✅ Kubernetes removal complete. A reboot is recommended to ensure all changes take effect."
echo "   You may want to manually run 'swapon -a' to re-enable swap immediately."

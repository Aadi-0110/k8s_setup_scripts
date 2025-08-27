#!/usr/bin/env bash
# reset-k8s.sh
set -euo pipefail
echo "Resetting Kubernetes on $(hostname)…"

sudo kubeadm reset -f
sudo systemctl disable --now kubelet || true
sudo rm -rf /etc/kubernetes /var/lib/etcd /etc/cni/net.d
sudo rm -rf /etc/k8s-iface
echo "Node cleaned. Reboot is recommended."

#!/usr/bin/env bash
# init-master.sh
set -euo pipefail

NIC=$(cat /etc/k8s-iface/nic)
IP=$(cat /etc/k8s-iface/ip)
POD_CIDR=10.244.0.0/16
SVC_CIDR=10.96.0.0/12

echo "=== Initialising control plane on $IP ($NIC) ==="

sudo kubeadm init \
  --apiserver-advertise-address="$IP" \
  --control-plane-endpoint=k8s.lab.local \
  --pod-network-cidr="$POD_CIDR" \
  --service-cidr="$SVC_CIDR"

# kubectl for the current user
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# Flannel overlay and NIC pinning[100]
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
echo "Waiting for Flannel daemonset to be created..."
kubectl -n kube-flannel wait --for=condition=available --timeout=120s daemonset/kube-flannel-ds
kubectl -n kube-flannel set env daemonset/kube-flannel-ds FLANNELD_IFACE="$NIC"

echo "Waiting for cluster networking to be ready..."
kubectl -n kube-flannel rollout status daemonset/kube-flannel-ds --timeout=300s

# --- OPTIONAL: schedule workloads on master ------------------------------
read -rp "Allow regular pods on the master? [y/N]: " SCHED
if [[ "$SCHED" =~ ^[Yy]$ ]]; then
  kubectl taint nodes --all node-role.kubernetes.io/control-plane- \
    && echo "Taint removed – master can now run workloads."
else
  echo "Keeping NoSchedule taint (best practice for prod)[113]."
fi

# --- print & save join command ------------------------------------------
JOIN=$(kubeadm token create --print-join-command)
echo -e "\n>>> Worker join command:\n$JOIN\n"
echo "$JOIN" > ~/kubeadm-join.sh && chmod +x ~/kubeadm-join.sh

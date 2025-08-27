#!/usr/bin/env bash
# join-worker.sh
set -euo pipefail

[[ -f /etc/k8s-iface/ip ]] || { echo "Run install-k8s-common.sh first"; exit 1; }

read -rp "Paste the kubeadm join command from the master: " JOIN_CMD
sudo $JOIN_CMD

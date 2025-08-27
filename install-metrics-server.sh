#!/usr/bin/env bash
# install-metrics-server-lite.sh
#
# Installs the upstream Metrics-Server manifest and immediately
# patches the Deployment so it works on most bare-metal clusters.
# – Requires: kubectl already pointing at your cluster.

set -euo pipefail

echo "▶️  Applying upstream Metrics-Server manifest…"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "▶️  Patching Deployment with bare-metal flags…"
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[
        {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
        {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"}
      ]'

echo "▶️  Waiting for rollout…"
kubectl -n kube-system rollout status deployment/metrics-server --timeout=120s

echo "✅  Metrics-Server ready.  Try:"
echo "   kubectl top nodes"
echo "   kubectl top pods -A"

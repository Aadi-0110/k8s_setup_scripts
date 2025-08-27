#!/usr/bin/env bash
# install-k8s-dashboard.sh
#
# Installs the upstream Kubernetes Dashboard with the “recommended”
# manifest, then creates an admin ServiceAccount + ClusterRoleBinding
# and shows you the login token.
#
# Requirements
#   • kubectl already points at your cluster and has cluster-admin rights
#   • curl available (only for downloading the manifest)

set -euo pipefail

DASH_NS=kubernetes-dashboard
SA_NAME=dashboard-admin-sa

echo "▶️  1/4  Deploying the official Dashboard manifest…"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

echo "▶️  2/4  Waiting for the dashboard pod to be Ready…"
kubectl -n $DASH_NS rollout status deployment/kubernetes-dashboard --timeout=120s

echo "▶️  3/4  Creating an admin ServiceAccount + ClusterRoleBinding…"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SA_NAME
  namespace: $DASH_NS
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $SA_NAME
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: $SA_NAME
  namespace: $DASH_NS
EOF

echo "▶️  4/4  Fetching the login token…"
TOKEN=$(kubectl -n $DASH_NS create token $SA_NAME)
echo ""
echo "=============================================="
echo "  Dashboard admin token:"
echo ""
echo "$TOKEN"
echo "=============================================="
echo ""
echo "Access the UI with:"
echo "  kubectl -n $DASH_NS port-forward svc/kubernetes-dashboard 8443:443"
echo "Then open https://localhost:8443 in your browser and paste the token."

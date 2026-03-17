#!/bin/bash
set -e
source "$(dirname "$0")/load-env.sh"

echo "============================================"
echo "  Step 1: K3d 클러스터 생성"
echo "  클러스터명: ${CLUSTER_NAME}"
echo "============================================"

# 기존 클러스터 삭제 (있으면)
k3d cluster delete "${CLUSTER_NAME}" 2>/dev/null || true

# 새 클러스터 생성
k3d cluster create "${CLUSTER_NAME}" \
  --port "${K3D_LB_HTTP_PORT:-8080}:80@loadbalancer" \
  --port "${K3D_LB_HTTPS_PORT:-8443}:443@loadbalancer" \
  --agents "${K3D_AGENTS:-1}" \
  --wait

echo ""
echo "✅ K3d 클러스터 생성 완료!"
kubectl cluster-info
echo ""
kubectl get nodes

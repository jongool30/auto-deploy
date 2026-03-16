#!/bin/bash
set -e

echo "============================================"
echo "  Step 1: K3d 클러스터 생성"
echo "============================================"

# 기존 클러스터 삭제 (있으면)
k3d cluster delete automation-cluster 2>/dev/null || true

# 새 클러스터 생성
k3d cluster create automation-cluster \
  --port "8080:80@loadbalancer" \
  --port "8443:443@loadbalancer" \
  --agents 1 \
  --wait

echo ""
echo "✅ K3d 클러스터 생성 완료!"
kubectl cluster-info
echo ""
kubectl get nodes

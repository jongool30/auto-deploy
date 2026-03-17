#!/bin/bash
set -e
source "$(dirname "$0")/load-env.sh"

echo "============================================"
echo "  Step 3: ArgoCD Application 등록"
echo "============================================"

REPO_URL="https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}.git"
echo "📦 Repository: $REPO_URL"
echo "📂 Branch: ${GITHUB_BRANCH}"

# K8s namespace 생성
kubectl apply -f k8s/namespace.yaml

# GHCR imagePullSecret 생성
kubectl create secret docker-registry ghcr-secret \
  --docker-server=${DOCKER_REGISTRY:-ghcr.io} \
  --docker-username=${GITHUB_USERNAME} \
  --docker-password=$(gh auth token) \
  --namespace=${K8S_NAMESPACE:-auto-deploy} \
  --dry-run=client -o yaml | kubectl apply -f -

# ArgoCD Application 생성
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME:-auto-deploy-api}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: ${GITHUB_BRANCH}
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: ${K8S_NAMESPACE:-auto-deploy}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

echo ""
echo "✅ ArgoCD Application 등록 완료!"
echo ""
echo "🔄 자동 동기화 설정됨:"
echo "   - GitHub k8s/ 디렉토리 변경 → 자동 배포"
echo "   - Self-Heal 활성화 (수동 변경 시 자동 복구)"
echo "   - Auto-Prune 활성화 (삭제된 리소스 자동 정리)"

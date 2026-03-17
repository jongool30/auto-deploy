#!/bin/bash
set -e
source "$(dirname "$0")/load-env.sh"

echo "============================================"
echo "  Step 2: ArgoCD 설치"
echo "============================================"

# ArgoCD 네임스페이스 생성
kubectl create namespace argocd 2>/dev/null || echo "argocd namespace already exists"

# ArgoCD 설치
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "⏳ ArgoCD Pod 시작 대기 중..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo ""
echo "✅ ArgoCD 설치 완료!"

# ArgoCD 초기 비밀번호 출력
echo ""
echo "============================================"
echo "  ArgoCD 접속 정보"
echo "============================================"
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "  URL:      https://localhost:${ARGOCD_PORT:-9090}"
echo "  Username: admin"
echo "  Password: $ARGO_PWD"
echo "============================================"
echo ""
echo "💡 포트포워딩 명령어:"
echo "  kubectl port-forward svc/argocd-server -n argocd ${ARGOCD_PORT:-9090}:443"
echo "  → https://localhost:${ARGOCD_PORT:-9090} 으로 접속"

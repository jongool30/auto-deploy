#!/bin/bash
set -e

echo "============================================"
echo "  Step 3: ArgoCD Application 등록"
echo "============================================"

# GitHub 사용자명 자동 감지
GITHUB_USER=$(gh api user -q '.login' 2>/dev/null || echo "OWNER")

if [ "$GITHUB_USER" = "OWNER" ]; then
  echo "⚠️  GitHub CLI 로그인이 필요합니다: gh auth login"
  read -p "GitHub 사용자명을 입력하세요: " GITHUB_USER
fi

REPO_URL="https://github.com/${GITHUB_USER}/auto-deploy.git"

echo "📦 Repository: $REPO_URL"

# K8s namespace 생성
kubectl apply -f k8s/namespace.yaml

# ArgoCD Application 생성
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: auto-deploy-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: auto-deploy
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

#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════╗"
echo "║  🚀 전체 자동화 파이프라인 설정 시작          ║"
echo "║  K3d + ArgoCD + GitHub + Docker              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# ────────────────────────────────────────
# 0. 사전 체크
# ────────────────────────────────────────
echo "🔍 환경 체크..."
command -v docker >/dev/null 2>&1 || { echo "❌ Docker가 설치되어 있지 않습니다."; exit 1; }
command -v k3d >/dev/null 2>&1    || { echo "❌ k3d가 설치되어 있지 않습니다."; exit 1; }
command -v kubectl >/dev/null 2>&1|| { echo "❌ kubectl이 설치되어 있지 않습니다."; exit 1; }
command -v gh >/dev/null 2>&1     || { echo "❌ GitHub CLI가 설치되어 있지 않습니다."; exit 1; }

docker info >/dev/null 2>&1 || { echo "❌ Docker Desktop이 실행 중이지 않습니다."; exit 1; }
echo "✅ 모든 도구 확인 완료"
echo ""

# ────────────────────────────────────────
# 1. K3d 클러스터
# ────────────────────────────────────────
bash "$SCRIPT_DIR/01-setup-cluster.sh"
echo ""

# ────────────────────────────────────────
# 2. Docker 이미지 빌드 & k3d에 로드
# ────────────────────────────────────────
echo "============================================"
echo "  Docker 이미지 빌드"
echo "============================================"
docker build -t auto-deploy-api:local "$PROJECT_DIR"
k3d image import auto-deploy-api:local -c automation-cluster
echo "✅ Docker 이미지 빌드 및 클러스터 로드 완료"
echo ""

# ────────────────────────────────────────
# 3. ArgoCD 설치
# ────────────────────────────────────────
bash "$SCRIPT_DIR/02-install-argocd.sh"
echo ""

# ────────────────────────────────────────
# 4. GitHub Repo 생성 & Push
# ────────────────────────────────────────
echo "============================================"
echo "  GitHub Repository 설정"
echo "============================================"

GITHUB_USER=$(gh api user -q '.login' 2>/dev/null || echo "")
if [ -z "$GITHUB_USER" ]; then
  echo "⚠️  GitHub 로그인이 필요합니다."
  gh auth login
  GITHUB_USER=$(gh api user -q '.login')
fi

# deployment.yaml에서 OWNER를 실제 사용자명으로 변경
sed -i "s|OWNER|${GITHUB_USER}|g" k8s/deployment.yaml

# Git 초기화 및 push
if [ ! -d .git ]; then
  git init
  git add .
  git commit -m "feat: initial project setup with FastAPI + K8s + ArgoCD + CI/CD"
fi

# GitHub 레포 생성 (없으면)
gh repo create auto-deploy --public --source=. --remote=origin 2>/dev/null || echo "Repo already exists"
git push -u origin main 2>/dev/null || git push -u origin master

echo "✅ GitHub 레포 설정 완료: https://github.com/${GITHUB_USER}/auto-deploy"
echo ""

# ────────────────────────────────────────
# 5. ArgoCD Application 등록
# ────────────────────────────────────────
bash "$SCRIPT_DIR/03-configure-argocd-app.sh"
echo ""

# ────────────────────────────────────────
# 완료
# ────────────────────────────────────────
echo "╔══════════════════════════════════════════════╗"
echo "║  🎉 전체 설정 완료!                           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "📋 파이프라인 흐름:"
echo "   1. 코드 수정 → git push"
echo "   2. GitHub Actions → 테스트 → Docker Build → GHCR Push"
echo "   3. GitHub Actions → k8s/deployment.yaml 이미지 태그 업데이트"
echo "   4. ArgoCD → 변경 감지 → K3s 자동 배포"
echo ""
echo "🔧 유용한 명령어:"
echo "   ArgoCD UI:   kubectl port-forward svc/argocd-server -n argocd 9090:443"
echo "   앱 상태:     kubectl get pods -n auto-deploy"
echo "   앱 접속:     curl http://localhost:8080/"
echo "   로그 확인:   kubectl logs -f -l app=auto-deploy-api -n auto-deploy"

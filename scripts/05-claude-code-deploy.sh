#!/bin/bash
# ============================================
# Claude Code 연동 자동 배포 스크립트
# ============================================
# 사용법:
#   ./scripts/05-claude-code-deploy.sh "변경 사항 메시지"
#   claude -p "app/main.py에 /users 추가해줘" && ./scripts/05-claude-code-deploy.sh "feat: add users"

set -e
source "$(dirname "$0")/load-env.sh"

COMMIT_MSG=${1:-"feat: auto-update by Claude Code"}
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🤖 Claude Code 자동 배포 파이프라인"
echo "============================================"

# 1. 변경사항 확인
if git diff --quiet && git diff --staged --quiet; then
  echo "⚠️  변경사항이 없습니다."
  exit 0
fi

echo "📝 변경된 파일:"
git status --short
echo ""

# 2. Docker Compose로 로컬 테스트
echo "🧪 로컬 Docker Compose 테스트..."
docker compose up -d --build api
sleep 3

HEALTH=$(curl -s http://localhost:${COMPOSE_APP_PORT:-8000}/health 2>/dev/null || echo '{"status":"failed"}')
if echo "$HEALTH" | grep -q '"healthy"'; then
  echo "✅ 헬스체크 통과!"
else
  echo "❌ 헬스체크 실패: $HEALTH"
  docker compose logs api
  docker compose down
  exit 1
fi
docker compose down

# 3. 커밋 & 푸시
git add -A
git commit -m "$COMMIT_MSG

Co-Authored-By: Claude Code <noreply@anthropic.com>"

git push origin "${GITHUB_BRANCH}"

echo ""
echo "✅ GitHub에 Push 완료!"
echo ""
echo "⏳ GitHub Actions 파이프라인 실행 중..."
echo "   → 테스트 → Docker Build → Manifest 업데이트 → ArgoCD 자동 배포"
echo ""
echo "📊 Actions 상태 확인:"
echo "   gh run list --limit 1"
echo ""
echo "🔍 ArgoCD 동기화 확인:"
echo "   kubectl get application ${APP_NAME} -n argocd"
echo "   kubectl get pods -n ${K8S_NAMESPACE}"

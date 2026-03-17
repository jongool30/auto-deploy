#!/bin/bash
# ============================================
# .env 파일 로드 공통 함수
# ============================================
# 사용법: source scripts/load-env.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ .env 파일이 없습니다."
  echo "   cp .env.example .env 로 생성 후 값을 수정하세요."
  exit 1
fi

# .env 파일 로드 (주석, 빈줄 무시)
set -a
while IFS='=' read -r key value; do
  # 주석, 빈줄 건너뛰기
  [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
  # 앞뒤 공백 제거
  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs)
  # 변수 치환 없이 그대로 export
  export "$key"="$value"
done < "$ENV_FILE"
set +a

echo "✅ .env 설정 로드 완료"
echo "   GITHUB: ${GITHUB_USERNAME}/${GITHUB_REPO} (${GITHUB_BRANCH})"
echo "   IMAGE:  ${IMAGE_NAME}:${IMAGE_TAG}"
echo "   CLUSTER: ${CLUSTER_NAME}"

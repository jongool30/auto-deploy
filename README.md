# 🚀 Auto Deploy - GitOps 자동화 파이프라인

> Claude Code + ArgoCD + K3s(k3d) + Docker + GitHub 기반 완전 자동화 배포 시스템

## 아키텍처

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐     ┌─────────────┐
│ Claude Code │────▶│   GitHub Push    │────▶│   GitHub    │────▶│    GHCR     │
│ (코드 수정)  │     │   (main branch)  │     │   Actions   │     │ (Docker Hub)│
└─────────────┘     └──────────────────┘     └──────┬──────┘     └──────┬──────┘
                                                     │                   │
                                                     ▼                   │
                                              ┌──────────────┐          │
                                              │ k8s manifest │          │
                                              │ 이미지 태그    │          │
                                              │ 자동 업데이트   │          │
                                              └──────┬───────┘          │
                                                     │                   │
                                                     ▼                   ▼
                                              ┌──────────────┐   ┌──────────────┐
                                              │   ArgoCD     │──▶│  K3s(k3d)   │
                                              │ (변경 감지)    │   │  (자동 배포)  │
                                              └──────────────┘   └──────────────┘
```

## 프로젝트 구조

```
auto-deploy/
├── app/                          # FastAPI 애플리케이션
│   ├── main.py                   # API 엔드포인트
│   └── requirements.txt          # Python 의존성
├── k8s/                          # Kubernetes 매니페스트 (ArgoCD 감시 대상)
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── scripts/                      # 자동화 스크립트
│   ├── 01-setup-cluster.sh       # K3d 클러스터 생성
│   ├── 02-install-argocd.sh      # ArgoCD 설치
│   ├── 03-configure-argocd-app.sh # ArgoCD App 등록
│   ├── 04-full-setup.sh          # 전체 한번에 설정
│   └── 05-claude-code-deploy.sh  # Claude Code 연동 배포
├── .github/workflows/
│   └── ci-cd.yaml                # GitHub Actions CI/CD
├── Dockerfile
├── .dockerignore
└── .gitignore
```

## 사전 요구사항

- [x] Docker Desktop
- [x] kubectl
- [x] k3d (`curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`)
- [x] GitHub CLI (`winget install GitHub.cli`)

## 빠른 시작

### 1단계: 사전 준비
```bash
# Docker Desktop 실행 (GUI에서 시작)
# GitHub CLI 로그인
gh auth login
```

### 2단계: 전체 자동 설정
```bash
bash scripts/04-full-setup.sh
```

이 스크립트가 자동으로:
1. K3d 클러스터 생성
2. Docker 이미지 빌드 & 로드
3. ArgoCD 설치
4. GitHub 레포 생성 & Push
5. ArgoCD Application 등록

### 3단계: 확인
```bash
# ArgoCD UI 접속
kubectl port-forward svc/argocd-server -n argocd 9090:443
# → https://localhost:9090

# 앱 접속
curl http://localhost:8080/

# Pod 상태 확인
kubectl get pods -n auto-deploy
```

## Claude Code 연동 사용법

```bash
# 방법 1: Claude Code로 코드 수정 후 자동 배포
claude -p "app/main.py에 /users 엔드포인트 추가해줘"
bash scripts/05-claude-code-deploy.sh "feat: add users endpoint"

# 방법 2: 한 줄로 실행
claude -p "app/main.py에 /users 엔드포인트 추가해줘" && bash scripts/05-claude-code-deploy.sh "feat: add users endpoint"
```

## 파이프라인 흐름

1. **코드 수정** → `git push` to main
2. **GitHub Actions** → 테스트 → Docker Build → GHCR Push
3. **GitHub Actions** → `k8s/deployment.yaml` 이미지 태그 자동 업데이트
4. **ArgoCD** → 변경 감지 → K3s 자동 배포

## 유용한 명령어

```bash
# 클러스터 관리
k3d cluster list
k3d cluster start automation-cluster
k3d cluster stop automation-cluster
k3d cluster delete automation-cluster

# ArgoCD
kubectl get application -n argocd
kubectl port-forward svc/argocd-server -n argocd 9090:443

# 앱 모니터링
kubectl get pods -n auto-deploy
kubectl logs -f -l app=auto-deploy-api -n auto-deploy
kubectl describe deployment auto-deploy-api -n auto-deploy
```

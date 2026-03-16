# 📘 Auto Deploy 자동화 파이프라인 운영 메뉴얼

> **작성일**: 2026-03-16
> **GitHub**: https://github.com/jongool30/auto-deploy
> **기술 스택**: Claude Code + ArgoCD + K3s(k3d) + Docker + GitHub Actions

---

## 📋 목차

1. [현재 구성 상태](#1-현재-구성-상태)
2. [일상 운영 가이드](#2-일상-운영-가이드)
3. [코드 변경 → 자동 배포 흐름](#3-코드-변경--자동-배포-흐름)
4. [ArgoCD 사용법](#4-argocd-사용법)
5. [모니터링 & 디버깅](#5-모니터링--디버깅)
6. [클러스터 관리](#6-클러스터-관리)
7. [문제 해결 (Troubleshooting)](#7-문제-해결-troubleshooting)

---

## 1. 현재 구성 상태

### 인프라 구성도
```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Claude Code │────▶│   GitHub     │────▶│  GitHub      │
│  (코드 수정)  │     │   (Push)     │     │  Actions     │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                                          ┌───────▼───────┐
                                          │  GHCR         │
                                          │  (Docker Hub) │
                                          └───────┬───────┘
                                                  │
                     ┌──────────────┐     ┌───────▼───────┐
                     │   ArgoCD     │◀────│  k8s manifest │
                     │   (자동 Sync) │     │  (자동 업데이트)│
                     └──────┬───────┘     └───────────────┘
                            │
                     ┌──────▼───────┐
                     │  K3s (k3d)   │
                     │  2 replicas  │
                     └──────────────┘
```

### 접속 정보

| 항목 | 정보 |
|------|------|
| **ArgoCD UI** | `kubectl port-forward svc/argocd-server -n argocd 9090:443` → https://localhost:9090 |
| **ArgoCD 계정** | ID: `admin` / PW: `GNHasSSBDY363QOL` |
| **API 앱** | `kubectl port-forward svc/auto-deploy-api -n auto-deploy 8888:80` → http://localhost:8888 |
| **GitHub Repo** | https://github.com/jongool30/auto-deploy |
| **Docker Image** | `ghcr.io/jongool30/auto-deploy:latest` |

### API 엔드포인트

| 경로 | 설명 | 응답 예시 |
|------|------|-----------|
| `GET /` | 서비스 정보 | `{"service":"auto-deploy-api","version":"1.0.0"}` |
| `GET /health` | 헬스 체크 | `{"status":"healthy"}` |
| `GET /info` | 환경 정보 | `{"app":"auto-deploy-api","environment":"production"}` |

---

## 2. 일상 운영 가이드

### 2.1 아침에 PC 켤 때

```bash
# 1. Docker Desktop 실행 (시작 메뉴에서)

# 2. 클러스터 확인 (Docker Desktop 시작 후 30초 기다림)
k3d cluster list
kubectl get nodes

# 3. Pod 상태 확인
kubectl get pods -n auto-deploy
kubectl get pods -n argocd
```

### 2.2 작업 종료 시

```bash
# 클러스터 중지 (Docker Desktop 끄면 자동 중지)
k3d cluster stop automation-cluster

# 또는 Docker Desktop만 종료
```

### 2.3 다음날 재시작

```bash
# Docker Desktop 실행 후
k3d cluster start automation-cluster

# kubeconfig 확인 (연결 안 될 때)
# ~/.kube/config의 server를 https://127.0.0.1:포트 로 변경
k3d kubeconfig merge automation-cluster --kubeconfig-merge-default
```

---

## 3. 코드 변경 → 자동 배포 흐름

### 방법 1: Claude Code로 자동 배포 (추천)

```bash
# 1. Claude Code로 코드 수정
claude -p "app/main.py에 /users 엔드포인트를 추가해줘"

# 2. 자동 배포 스크립트 실행
bash scripts/05-claude-code-deploy.sh "feat: add users endpoint"
```

### 방법 2: 수동 코드 수정 후 배포

```bash
# 1. 코드 수정 (편집기에서)
# 2. Git commit & push
git add -A
git commit -m "feat: 새 기능 설명"
git push origin master

# 3. GitHub Actions 파이프라인 자동 실행
#    테스트 → Docker Build → GHCR Push → manifest 업데이트

# 4. ArgoCD 자동 배포
#    manifest 변경 감지 → K3s 자동 배포
```

### 방법 3: 빠른 로컬 테스트 후 배포

```bash
# 1. 로컬에서 Docker로 테스트
docker build -t auto-deploy-api:test .
docker run -p 8000:8000 auto-deploy-api:test

# 2. 테스트 확인
curl http://localhost:8000/health

# 3. 문제 없으면 push
git add -A && git commit -m "feat: 변경사항" && git push
```

### 배포 확인

```bash
# GitHub Actions 상태
gh run list --limit 3

# ArgoCD 동기화 상태
kubectl get application auto-deploy-api -n argocd -o wide

# Pod 상태
kubectl get pods -n auto-deploy
```

---

## 4. ArgoCD 사용법

### 4.1 ArgoCD UI 접속

```bash
# 포트포워딩 시작
kubectl port-forward svc/argocd-server -n argocd 9090:443

# 브라우저에서 접속
# https://localhost:9090
# ID: admin
# PW: GNHasSSBDY363QOL
```

### 4.2 ArgoCD 주요 기능

| 기능 | 설명 |
|------|------|
| **Auto Sync** | GitHub k8s/ 디렉토리 변경 → 자동 배포 (설정 완료) |
| **Self Heal** | 누군가 수동으로 Pod 삭제해도 자동 복구 (설정 완료) |
| **Auto Prune** | 삭제된 리소스 자동 정리 (설정 완료) |
| **Rollback** | UI에서 이전 버전으로 원클릭 롤백 가능 |

### 4.3 수동 Sync 트리거

```bash
# kubectl로 강제 sync
kubectl patch application auto-deploy-api -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

---

## 5. 모니터링 & 디버깅

### 5.1 Pod 상태 확인

```bash
# 전체 리소스 현황
kubectl get all -n auto-deploy

# Pod 상세 정보
kubectl describe pod <POD_NAME> -n auto-deploy

# 실시간 로그
kubectl logs -f -l app=auto-deploy-api -n auto-deploy

# 이전 Pod 로그 (크래시 시)
kubectl logs <POD_NAME> -n auto-deploy --previous
```

### 5.2 API 직접 호출 테스트

```bash
# 포트포워딩
kubectl port-forward svc/auto-deploy-api -n auto-deploy 8888:80

# API 테스트
curl http://localhost:8888/
curl http://localhost:8888/health
curl http://localhost:8888/info
```

### 5.3 ArgoCD 상태 확인

```bash
# Application 상태
kubectl get application -n argocd

# 상세 동기화 상태
kubectl describe application auto-deploy-api -n argocd
```

---

## 6. 클러스터 관리

### 6.1 클러스터 시작/중지/삭제

```bash
# 시작
k3d cluster start automation-cluster

# 중지
k3d cluster stop automation-cluster

# 삭제 (주의: 모든 데이터 삭제됨)
k3d cluster delete automation-cluster

# 재생성
bash scripts/01-setup-cluster.sh
bash scripts/02-install-argocd.sh
bash scripts/03-configure-argocd-app.sh
```

### 6.2 이미지 관련

```bash
# GHCR 로그인
echo $(gh auth token) | docker login ghcr.io -u jongool30 --password-stdin

# 이미지 빌드 & Push
docker build -t ghcr.io/jongool30/auto-deploy:latest .
docker push ghcr.io/jongool30/auto-deploy:latest

# k3d에 직접 이미지 로드 (GHCR 없이 로컬 테스트)
docker build -t auto-deploy-api:local .
k3d image import auto-deploy-api:local -c automation-cluster
```

### 6.3 Secret 관리

```bash
# GHCR imagePullSecret 재생성 (토큰 만료 시)
kubectl delete secret ghcr-secret -n auto-deploy
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=jongool30 \
  --docker-password=$(gh auth token) \
  --namespace=auto-deploy
```

---

## 7. 문제 해결 (Troubleshooting)

### 문제: kubectl 연결 안 됨

```bash
# 원인: kubeconfig의 server 주소가 host.docker.internal로 되어 있음
# 해결:
k3d kubeconfig merge automation-cluster --kubeconfig-merge-default
# 그 후 ~/.kube/config 에서 server 주소를 https://127.0.0.1:PORT 로 변경
```

### 문제: Pod ErrImagePull

```bash
# 원인 1: GHCR 토큰 만료
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=jongool30 \
  --docker-password=$(gh auth token) \
  --namespace=auto-deploy \
  --dry-run=client -o yaml | kubectl apply -f -

# 원인 2: 이미지 태그 오류
kubectl describe pod <POD_NAME> -n auto-deploy | grep -A5 "Events"
```

### 문제: ArgoCD Sync 안 됨

```bash
# 강제 Refresh
kubectl patch application auto-deploy-api -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# ArgoCD 서버 재시작
kubectl rollout restart deployment argocd-server -n argocd
```

### 문제: GitHub Actions 실패

```bash
# 최근 실행 확인
gh run list --limit 5

# 실패한 run 로그 보기
gh run view <RUN_ID> --log-failed
```

### 문제: Docker Desktop 시작 후 k3d 클러스터 안 보임

```bash
# 클러스터 상태 확인
k3d cluster list

# 안 보이면 재시작
k3d cluster start automation-cluster

# 그래도 안 되면 재생성
k3d cluster delete automation-cluster
bash scripts/04-full-setup.sh
```

---

## 📎 자주 쓰는 명령어 모음

```bash
# === 상태 확인 ===
kubectl get pods -n auto-deploy          # Pod 상태
kubectl get all -n auto-deploy           # 전체 리소스
kubectl get application -n argocd        # ArgoCD 상태
gh run list --limit 3                    # GitHub Actions

# === ArgoCD UI ===
kubectl port-forward svc/argocd-server -n argocd 9090:443

# === API 테스트 ===
kubectl port-forward svc/auto-deploy-api -n auto-deploy 8888:80
curl http://localhost:8888/health

# === 로그 ===
kubectl logs -f -l app=auto-deploy-api -n auto-deploy

# === Claude Code 배포 ===
bash scripts/05-claude-code-deploy.sh "변경 메시지"

# === 클러스터 관리 ===
k3d cluster start automation-cluster
k3d cluster stop automation-cluster
```

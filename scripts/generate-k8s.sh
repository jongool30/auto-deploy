#!/bin/bash
# ============================================
# .env 기반 K8s manifest 자동 생성
# ============================================
# .env 값이 변경되면 이 스크립트로 k8s/ 파일을 재생성합니다.
# 사용법: bash scripts/generate-k8s.sh

set -e
source "$(dirname "$0")/load-env.sh"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
K8S_DIR="$PROJECT_DIR/k8s"
mkdir -p "$K8S_DIR"

echo "============================================"
echo "  K8s Manifest 생성 (.env 기반)"
echo "============================================"

# ── namespace.yaml ──
cat > "$K8S_DIR/namespace.yaml" <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${K8S_NAMESPACE}
  labels:
    app: ${APP_NAME}
EOF

# ── deployment.yaml ──
cat > "$K8S_DIR/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${APP_NAME}
  namespace: ${K8S_NAMESPACE}
  labels:
    app: ${APP_NAME}
spec:
  replicas: ${APP_REPLICAS}
  selector:
    matchLabels:
      app: ${APP_NAME}
  template:
    metadata:
      labels:
        app: ${APP_NAME}
    spec:
      imagePullSecrets:
        - name: ghcr-secret
      containers:
        - name: api
          image: ${IMAGE_NAME}:${IMAGE_TAG}
          ports:
            - containerPort: ${APP_PORT}
          env:
            - name: ENVIRONMENT
              value: "${ENVIRONMENT}"
            - name: APP_VERSION
              value: "${APP_VERSION}"
            - name: DEPLOYED_AT
              value: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
          livenessProbe:
            httpGet:
              path: /health
              port: ${APP_PORT}
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: ${APP_PORT}
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "200m"
EOF

# ── service.yaml ──
cat > "$K8S_DIR/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ${APP_NAME}
  namespace: ${K8S_NAMESPACE}
spec:
  type: ClusterIP
  selector:
    app: ${APP_NAME}
  ports:
    - port: 80
      targetPort: ${APP_PORT}
      protocol: TCP
EOF

# ── ingress.yaml ──
cat > "$K8S_DIR/ingress.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
  namespace: ${K8S_NAMESPACE}
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${APP_NAME}
                port:
                  number: 80
EOF

echo ""
echo "✅ K8s Manifest 생성 완료!"
echo "   - $K8S_DIR/namespace.yaml"
echo "   - $K8S_DIR/deployment.yaml"
echo "   - $K8S_DIR/service.yaml"
echo "   - $K8S_DIR/ingress.yaml"
echo ""
echo "💡 변경사항 확인: git diff k8s/"

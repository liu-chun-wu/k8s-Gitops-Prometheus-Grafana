# Getting Started

## 前置需求

- Docker Desktop / Docker Engine
- Kind (Kubernetes in Docker)
- kubectl
- make
- git

### 安裝工具

**macOS:**
```bash
brew install kind kubectl git
```

**Linux:**
```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

## 快速開始 (5分鐘)

### 方式一：一鍵設置（推薦）

```bash
# 完整環境設置（含 Ingress 和監控）
make quickstart

# 配置本地 DNS
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'

# 查看訪問資訊
make access
```

### 方式二：分步設置

```bash
# 1. 設置環境
make setup      # 創建 Kind 叢集 + ArgoCD

# 2. 配置 Ingress
make ingress    # 安裝 NGINX + 設定 ArgoCD Ingress

# 3. 部署應用
make deploy     # 部署所有應用和監控
```

## 服務訪問

### Ingress 訪問（推薦）
- **ArgoCD**: http://argocd.local (admin/admin123)
- **Grafana**: http://localhost:3001 (admin/admin123)
- **Prometheus**: http://localhost:9090

### Port Forward 訪問
```bash
make forward
```
- **ArgoCD**: http://localhost:8080
- **Grafana**: http://localhost:3001
- **Prometheus**: http://localhost:9090

## 系統架構

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│   GitHub    │────▶│   ArgoCD    │────▶│  Kubernetes  │
│    Repo     │     │  (GitOps)   │     │   Cluster    │
└─────────────┘     └─────────────┘     └──────────────┘
                           │                     │
                           ▼                     ▼
                    ┌─────────────┐      ┌──────────────┐
                    │  Monitoring │      │  Applications│
                    │  Prometheus │      │   podinfo    │
                    │   Grafana   │      └──────────────┘
                    └─────────────┘
```

### 核心組件

- **Kind Cluster**: 本地 Kubernetes 環境
- **Local Registry**: localhost:5001 容器映像倉庫
- **ArgoCD**: GitOps 持續部署
- **Prometheus**: 指標收集
- **Grafana**: 監控儀表板
- **NGINX Ingress**: HTTP 路由

## 下一步

- [本地開發流程](local-development.md)
- [故障排除](troubleshooting.md)
- [命令參考](command-reference.md)
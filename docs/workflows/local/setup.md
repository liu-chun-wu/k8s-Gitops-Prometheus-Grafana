# 本地開發環境設置

本指南幫助您設置完整的本地 Kubernetes 開發環境，包含 Kind 叢集、本地 Registry 和必要的工具。

## 前置需求

### 必要工具
- **Docker Desktop**: 容器執行環境
- **kind**: 本地 K8s 叢集工具  
- **kubectl**: K8s CLI 工具
- **yq**: YAML 處理工具
- **git**: 版本控制

### 安裝指令

```bash
# macOS (使用 Homebrew)
brew install kind kubectl yq git

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/

# 驗證安裝
make check-prereqs
```

## 快速設置

```bash
# 一鍵設置完整環境
make quickstart
```

這會執行：
1. 創建 Kind 叢集
2. 設置本地 Registry (localhost:5001)
3. 安裝 ArgoCD
4. 部署監控系統
5. 部署應用

## 分步設置

### Step 1: 建立 Kind 叢集與 Registry

```bash
make setup-cluster
```

這會：
- 啟動 Registry 容器在 localhost:5001
- 建立 3 節點 Kind 叢集（1 control + 2 workers）
- 配置 containerd 使用本地 registry
- 設定網路連接

驗證：
```bash
kubectl get nodes
docker ps | grep kind-registry
```

### Step 2: 安裝 ArgoCD

```bash
make install-argocd
```

### Step 3: 設置 Ingress 和固定密碼

#### 3.1 安裝 NGINX Ingress Controller

```bash
# 安裝 Ingress Controller
make install-ingress
```

#### 3.2 配置 ArgoCD Ingress

```bash
# 設置 ArgoCD Ingress
make setup-argocd-ingress
```

#### 3.3 設定固定密碼（開發環境專用）

```bash
# 應用固定密碼配置
kubectl apply -f gitops/argocd/argocd-secret.yaml

# 重啟 ArgoCD Server 使密碼生效
kubectl rollout restart deployment argocd-server -n argocd
```

#### 3.4 配置本地 DNS

添加 hosts 記錄：
```bash
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'
```

#### 3.5 訪問 ArgoCD

- URL: http://argocd.local
- 用戶名: admin
- 密碼: admin123

> ⚠️ **安全提示**：固定密碼僅適用於開發環境，生產環境請使用 Secret 管理工具

### Step 4: 部署監控系統

```bash
make deploy-monitoring
```

### Step 5: 部署應用

```bash
# 只部署本地版本
make deploy-local

# 或部署所有應用
make deploy-apps
```

## 驗證安裝

```bash
# 檢查所有服務狀態
make status

# 測試 Registry 連接
make registry-test
```

## 訪問服務

### 使用 Ingress (推薦)
- ArgoCD: http://argocd.local (admin/admin123)
- Grafana: http://localhost:3001 (admin/admin123)
- Prometheus: http://localhost:9090

### 使用 Port Forward (備選)
```bash
make port-forward-all
```

服務將可在以下位置訪問：
- ArgoCD: http://localhost:8080 (admin/admin123)
- Grafana: http://localhost:3001 (admin/admin123)
- Prometheus: http://localhost:9090

## 下一步

- [開發流程](development.md) - 了解如何進行本地開發
- [故障排除](troubleshooting.md) - 常見問題解決

## 相關文檔

- [架構說明](../../getting-started/architecture.md)
- [Makefile 命令參考](../../reference/makefile-commands.md)
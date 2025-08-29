# GHCR (GitHub Container Registry) 設定指南

## 概述

GitHub Container Registry (GHCR) 是 GitHub 提供的容器映像託管服務。本專案支援使用 GHCR 作為映像來源，可以選擇公開或私有映像。

## 公開 vs 私有映像

### 公開映像（推薦用於開源專案）

**優點：**
- 無需設定認證
- 任何人都可以拉取映像
- 簡化部署流程

**設定步驟：**
1. 在 GitHub 上進入你的 Package 設定
2. 找到你的容器映像
3. 點擊 "Package settings"
4. 在 "Danger Zone" 區域，選擇 "Change visibility"
5. 選擇 "Public"

### 私有映像（推薦用於私有專案）

**優點：**
- 映像受保護，需要認證才能存取
- 適合包含敏感資訊的應用

**缺點：**
- 需要設定 Kubernetes secret
- 部署流程稍微複雜

## 檢查映像可存取性

```bash
# 檢查你的 GHCR 映像是否需要認證
make check-ghcr-access
```

## 設定私有映像認證

如果你使用私有 GHCR 映像，需要設定 Kubernetes secret：

### 步驟 1：建立 GitHub Personal Access Token (PAT)

1. 前往 GitHub Settings > Developer settings > Personal access tokens
2. 點擊 "Generate new token (classic)"
3. 給 token 一個描述性名稱（如 "k8s-ghcr-read"）
4. 選擇以下權限：
   - `read:packages` - 允許讀取容器映像
5. 點擊 "Generate token"
6. **重要：** 複製並安全保存這個 token，它只會顯示一次

### 步驟 2：建立 Kubernetes Secret

```bash
# 替換 YOUR_GITHUB_USERNAME 和 YOUR_GITHUB_PAT
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  -n demo-ghcr
```

或者使用 Makefile 命令查看指引：
```bash
make setup-ghcr-secret
```

### 步驟 3：在 Deployment 中使用 Secret

如果你的映像是私有的，確保 Deployment 包含 imagePullSecrets：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: podinfo
spec:
  template:
    spec:
      imagePullSecrets:
      - name: ghcr-secret
      containers:
      - name: podinfo
        image: ghcr.io/your-username/your-image:tag
```

## GitHub Actions 自動推送

本專案已配置 GitHub Actions 工作流程，會在推送到 main 分支時自動：
1. 構建 Docker 映像
2. 推送到 GHCR
3. 更新 Kubernetes manifests 中的映像標籤

GitHub Actions 使用內建的 `GITHUB_TOKEN`，不需要額外設定。

## 故障排除

### 問題：拉取映像時出現 "unauthorized" 錯誤

**解決方案：**
1. 檢查映像是否為私有：`make check-ghcr-access`
2. 如果是私有，確保已建立 secret：`kubectl get secret ghcr-secret -n demo-ghcr`
3. 確保 Deployment 包含 `imagePullSecrets`

### 問題：GitHub Actions 推送失敗

**解決方案：**
1. 確保 GitHub Actions 有正確的權限
2. 在 Repository Settings > Actions > General 中，確保 "Workflow permissions" 設為 "Read and write permissions"

## 最佳實踐

1. **開源專案**：使用公開映像，簡化社群貢獻
2. **私有專案**：使用私有映像，保護智慧財產
3. **PAT 管理**：
   - 設定最小必要權限
   - 定期輪換 token
   - 使用 Secret 管理工具（如 Sealed Secrets）在生產環境
4. **CI/CD**：讓 GitHub Actions 處理映像構建和推送，避免手動操作
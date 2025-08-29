# GHCR (GitHub Container Registry) 設置

本指南說明如何設置 GitHub Container Registry 進行自動化 CI/CD 部署。

## 前置需求

- GitHub 帳號與倉庫
- GitHub Actions 權限
- Docker 環境

## GitHub 設置

### 1. 啟用 GitHub Packages

1. 進入 GitHub Settings → Developer settings → Personal access tokens
2. 創建新的 token (classic) 或 fine-grained token
3. 勾選權限：
   - `write:packages` - 推送映像
   - `read:packages` - 拉取映像
   - `delete:packages` - 刪除映像（可選）

### 2. 設置 Repository Secrets

在您的 GitHub 倉庫中：

1. Settings → Secrets and variables → Actions
2. 添加以下 secrets（如需要）：
   - `GHCR_TOKEN` - 您的 Personal Access Token（通常使用內建 GITHUB_TOKEN 即可）

### 3. 配置 GitHub Actions 權限

Settings → Actions → General → Workflow permissions：
- 選擇 "Read and write permissions"
- 勾選 "Allow GitHub Actions to create and approve pull requests"

## GitHub Actions 工作流程

### 基本工作流程配置

檢查 `.github/workflows/release-ghcr.yml`：

```yaml
name: Build and Push to GHCR

on:
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/podinfo

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
```

### 權限說明

- `contents: write` - 允許提交變更到倉庫
- `packages: write` - 允許推送映像到 GHCR

## 本地測試 GHCR

### 1. 登入 GHCR

```bash
# 使用 Personal Access Token
echo $GHCR_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin

# 或使用 GitHub CLI
gh auth token | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

### 2. 手動推送映像

```bash
# 構建映像
docker build -t ghcr.io/YOUR_GITHUB_USERNAME/REPO_NAME/podinfo:test .

# 推送映像
docker push ghcr.io/YOUR_GITHUB_USERNAME/REPO_NAME/podinfo:test
```

### 3. 驗證映像

訪問：`https://github.com/users/YOUR_GITHUB_USERNAME/packages/container/package/REPO_NAME%2Fpodinfo`

## Kubernetes 配置

### 1. 創建 Image Pull Secret（私有倉庫）

如果您的 GHCR 映像是私有的：

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_TOKEN \
  --docker-email=YOUR_EMAIL \
  -n demo-ghcr
```

### 2. 更新 Deployment

在 `k8s/podinfo/overlays/dev-ghcr/kustomization.yaml`：

```yaml
images:
  - name: ghcr.io/stefanprodan/podinfo
    newName: ghcr.io/YOUR_GITHUB_USERNAME/REPO_NAME/podinfo
    newTag: main-SHA
```

如果需要 pull secret：
```yaml
# 在 deployment.yaml 中添加
spec:
  template:
    spec:
      imagePullSecrets:
      - name: ghcr-secret
```

## ArgoCD 配置

### 部署 GHCR 應用

```bash
# 部署 GHCR 版本的應用
make deploy-ghcr
```

### 配置自動同步

檢查 `gitops/argocd/apps/podinfo-ghcr.yaml`：

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

## 映像管理

### 查看所有映像

```bash
# 使用 GitHub CLI
gh api user/packages/container/REPO_NAME%2Fpodinfo/versions
```

### 清理舊映像

GitHub 提供自動清理政策：
1. Settings → Packages → Container registry
2. 設置保留政策（如保留最新 10 個版本）

## 故障排除

### 權限錯誤

如果 Actions 無法推送映像：
1. 確認 workflow 有 `packages: write` 權限
2. 確認使用正確的 registry URL：`ghcr.io`
3. 確認映像名稱為小寫

### 映像名稱規範

GHCR 要求：
- 全部小寫
- 格式：`ghcr.io/OWNER/REPO/IMAGE:TAG`
- OWNER 和 REPO 必須小寫

## 下一步

- [CI/CD 流程](ci-cd.md) - 了解完整的 CI/CD 流程
- [故障排除](troubleshooting.md) - 解決常見問題

## 相關文檔

- [本地開發設置](../local/setup.md) - 本地環境配置
- [GitHub Actions 官方文檔](https://docs.github.com/en/actions)
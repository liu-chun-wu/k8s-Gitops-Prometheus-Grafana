# GHCR 部署指南

GitHub Container Registry 是 GitHub 提供的容器映像託管服務，適合生產環境部署。

## 快速開始

```bash
make quickstart-ghcr    # 一鍵部署 GHCR 環境
make check-ghcr-access  # 檢查映像可訪問性
```

## 映像配置

### 公開映像（推薦）

**優點**：無需認證、簡化部署

**設定步驟**：
1. GitHub → Packages → 選擇映像
2. Package settings → Danger Zone
3. Change visibility → Public

### 私有映像

**設定 PAT Token**：
1. GitHub Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. 權限：`read:packages`
4. 保存 token

**創建 K8s Secret**：
```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_PAT \
  -n demo-ghcr
```

**Deployment 配置**：
```yaml
spec:
  template:
    spec:
      imagePullSecrets:
      - name: ghcr-secret
      containers:
      - image: ghcr.io/username/image:tag
```

## GitHub Actions CI/CD

**.github/workflows/docker-build.yml** 已配置：
- 自動構建映像
- 推送到 GHCR
- 更新 K8s manifests

**權限設置**：
Repository Settings → Actions → General → Workflow permissions → Read and write

## 開發流程

```bash
# 1. 推送代碼到 GitHub
git push origin main

# 2. Actions 自動構建並推送映像

# 3. ArgoCD 自動同步部署

# 4. 檢查部署狀態
make status
```

## 故障排除

| 問題 | 解決方案 |
|------|----------|
| unauthorized 錯誤 | 1. 檢查映像是否私有<br>2. 確認 secret 存在<br>3. 檢查 imagePullSecrets |
| Actions 推送失敗 | 確認 Workflow permissions 設為 Read and write |
| 映像未更新 | 1. 檢查 Actions 日誌<br>2. 確認 image tag 變更 |

## 最佳實踐

- **開源專案**：使用公開映像
- **私有專案**：使用私有映像 + PAT
- **Token 管理**：定期輪換、最小權限
- **生產環境**：使用 Sealed Secrets
# 本地開發指南

## 前置需求

| 工具 | 安裝命令 (macOS) | 用途 |
|------|-----------------|------|
| Docker | brew install docker | 容器運行環境 |
| Kind | brew install kind | 本地 K8s 叢集 |
| kubectl | brew install kubectl | K8s CLI |
| make | 內建 | 自動化工具 |

## 快速開始

### 一鍵設置
```bash
make quickstart-local    # 創建叢集 + 部署所有服務
make access             # 查看訪問資訊
```

### 分步設置
```bash
make setup-local        # 1. 創建叢集 + Local Registry
make install-argocd     # 2. 安裝 ArgoCD
make deploy-local       # 3. 部署本地應用
make deploy-monitoring  # 4. 部署監控
```

## 開發流程

### 快速開發循環
```bash
# 修改代碼 → 構建 → 推送 → 部署
make dev

# 檢查狀態
make status
```

### 手動步驟
```bash
# 1. 構建映像
docker build -t localhost:5001/podinfo:dev-$(git rev-parse --short HEAD) .

# 2. 推送到 Registry
docker push localhost:5001/podinfo:dev-$(git rev-parse --short HEAD)

# 3. 更新 Kustomization
yq -i '.images[0].newTag = "dev-'$(git rev-parse --short HEAD)'"' \
  k8s/podinfo/overlays/dev-local/kustomization.yaml
```

## Registry 管理

### 測試連接
```bash
make test
```

### 查看內容
```bash
# 列出所有映像
curl -s http://localhost:5001/v2/_catalog | jq

# 查看標籤
curl -s http://localhost:5001/v2/podinfo/tags/list | jq
```

## Git 工作流程

| 命令 | 說明 |
|------|------|
| `make update MSG="msg"` | 同步 + 提交 + 推送 |
| `make commit MSG="msg"` | 只提交 |
| `make sync` | 只同步 |
| `make push` | 只推送 |

## 常用操作

### 應用管理
```bash
# 重新部署
kubectl rollout restart deployment/local-podinfo -n demo-local

# 強制同步
kubectl patch application podinfo-local -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# 查看日誌
kubectl logs -n demo-local -l app=podinfo --tail=50
```

### Port Forward
```bash
# 單個服務
kubectl port-forward svc/local-podinfo -n demo-local 9898:9898

# 所有服務
make forward
```

## 故障排除

| 問題 | 解決方案 |
|------|----------|
| Registry 連接失敗 | `docker ps \| grep registry` 檢查容器 |
| Pod 無法拉取映像 | 確認映像標籤正確：`curl http://localhost:5001/v2/podinfo/tags/list` |
| ArgoCD OutOfSync | `make dev` 重新部署 |
| 叢集無回應 | `docker restart gitops-demo-control-plane` |

## 最佳實踐

1. **頻繁提交**：使用 `make update` 保持同步
2. **檢查狀態**：部署後執行 `make status`
3. **監控指標**：檢查 Grafana Dashboard
4. **清理資源**：不用時執行 `make clean`
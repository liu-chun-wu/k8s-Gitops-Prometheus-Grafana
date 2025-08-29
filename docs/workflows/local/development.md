# 本地開發流程

本指南說明如何使用本地 Registry 進行快速迭代開發。

## 開發循環概覽

```mermaid
graph LR
    A[修改代碼] --> B[構建映像]
    B --> C[推送到本地 Registry]
    C --> D[更新 Kustomization]
    D --> E[Git Commit]
    E --> F[ArgoCD 同步]
    F --> G[部署到叢集]
```

## 快速開發命令

### 一鍵發布
```bash
make dev-local-release
```

這會自動：
1. 構建 Docker 映像
2. 推送到本地 Registry (localhost:5001)
3. 更新 kustomization.yaml
4. 提交到 Git
5. 觸發 ArgoCD 同步

## 分步執行

### 1. 修改程式碼

編輯您的應用程式碼或 Dockerfile：
```bash
vi Dockerfile
```

### 2. 構建映像

```bash
make dev-local-build
```

實際執行：
```bash
SHA=$(git rev-parse --short HEAD)
docker build -t localhost:5001/podinfo:dev-${SHA} .
```

### 3. 推送到本地 Registry

```bash
make dev-local-push
```

驗證推送：
```bash
curl -s http://localhost:5001/v2/podinfo/tags/list | jq
```

### 4. 更新 Kustomization

```bash
make dev-local-update
```

這會更新 `k8s/podinfo/overlays/dev-local/kustomization.yaml`：
```yaml
images:
  - name: ghcr.io/stefanprodan/podinfo
    newName: localhost:5001/podinfo
    newTag: dev-${SHA}
```

### 5. 提交並推送

```bash
make dev-local-commit
```

或使用新的整合命令：
```bash
make git-commit-push MSG="feat: add new feature"
```

## ArgoCD 同步

### 自動同步
ArgoCD 配置了自動同步，會在 Git 變更後自動部署：
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

### 手動同步
如需立即同步：
```bash
kubectl patch application podinfo-local -n argocd \
  --type merge -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {}}}'
```

## 監控部署

### 查看 Pod 狀態
```bash
kubectl get pods -n demo-local -w
```

### 查看日誌
```bash
kubectl logs -n demo-local -l app=podinfo -f
```

### 查看 ArgoCD 狀態
```bash
kubectl get application podinfo-local -n argocd
```

## 測試應用

### 訪問應用
```bash
# Port forward
kubectl port-forward svc/local-podinfo -n demo-local 9898:9898

# 或使用 Makefile
make port-forward-podinfo-local
```

### 測試端點
```bash
# 健康檢查
curl http://localhost:9898/healthz

# 版本資訊
curl http://localhost:9898/version

# Metrics
curl http://localhost:9898/metrics
```

## 開發技巧

### 1. 使用 Watch 模式
監控 Pod 變化：
```bash
watch kubectl get pods -n demo-local
```

### 2. 快速重啟
強制重新部署：
```bash
kubectl rollout restart deploy/local-podinfo -n demo-local
```

### 3. 本地測試
在推送前本地測試：
```bash
docker run --rm -p 9898:9898 localhost:5001/podinfo:dev-${SHA}
```

### 4. 別名設置
添加到 ~/.bashrc 或 ~/.zshrc：
```bash
alias kl='kubectl -n demo-local'
alias kdp='kubectl describe pod -n demo-local'
alias klogs='kubectl logs -n demo-local'
```

## 清理資源

### 刪除應用
```bash
make delete-local
```

### 清理映像
```bash
docker image prune -f
```

## 下一步

- [故障排除](troubleshooting.md) - 解決常見問題
- [監控設置](../../operations/monitoring.md) - 設置 Prometheus 監控

## 相關文檔

- [GHCR 工作流程](../ghcr/ci-cd.md) - 生產環境部署
- [最佳實踐](../../reference/best-practices.md) - GitOps 最佳實踐
# 本地開發指南

## 開發流程

### 快速開發循環

```bash
# 1. 修改代碼
vim Dockerfile  # 或修改應用代碼

# 2. 構建、推送、部署
make dev

# 3. 檢查狀態
make status
```

### 手動步驟

#### 1. 構建映像
```bash
docker build -t localhost:5001/podinfo:dev-$(git rev-parse --short HEAD) .
```

#### 2. 推送到本地 Registry
```bash
docker push localhost:5001/podinfo:dev-$(git rev-parse --short HEAD)
```

#### 3. 更新 Kustomization
```bash
yq -i '.images[0].newTag = "dev-'$(git rev-parse --short HEAD)'"' \
  k8s/podinfo/overlays/dev-local/kustomization.yaml
```

#### 4. 提交並推送
```bash
make commit MSG="feat: update podinfo"
```

## Git 工作流程

### 提交變更
```bash
# 方式一：使用 make
make commit MSG="fix: resolve issue"

# 方式二：手動
git add -A
git commit -m "fix: resolve issue"
git push origin main
```

### 同步遠端
```bash
make sync  # 拉取最新變更
make push  # 推送本地變更
```

## 測試驗證

### 檢查應用狀態
```bash
# ArgoCD 應用狀態
kubectl get applications -n argocd

# Pod 狀態
kubectl get pods -n demo-local

# 服務日誌
kubectl logs -n demo-local -l app=podinfo
```

### 訪問應用
```bash
# Port forward 方式
kubectl port-forward svc/local-podinfo -n demo-local 9898:9898

# 訪問
curl http://localhost:9898
```

## Registry 管理

### 測試 Registry 連接
```bash
make test
```

### 查看 Registry 內容
```bash
# 列出所有映像
curl -s http://localhost:5001/v2/_catalog | jq

# 查看特定映像標籤
curl -s http://localhost:5001/v2/podinfo/tags/list | jq
```

## 常見任務

### 重新部署應用
```bash
kubectl rollout restart deployment/local-podinfo -n demo-local
```

### 強制同步 ArgoCD
```bash
kubectl patch application podinfo-local -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### 清理資源
```bash
# 刪除應用
kubectl delete application podinfo-local -n argocd

# 清理命名空間
kubectl delete namespace demo-local
```

## 最佳實踐

1. **頻繁提交**: 小步快跑，頻繁提交
2. **測試優先**: 部署前本地測試
3. **監控檢查**: 部署後檢查 Grafana 指標
4. **版本管理**: 使用語義化版本標籤

## 疑難排解

如遇問題，請參考 [故障排除指南](troubleshooting.md)
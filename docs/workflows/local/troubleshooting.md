# 本地開發故障排除

本指南幫助您解決本地開發環境中的常見問題。

## 常見問題

### 1. 映像拉取失敗 (ImagePullBackOff)

**症狀**：
```
NAME                           READY   STATUS             RESTARTS   AGE
local-podinfo-c886b8bf-6jttj   0/1     ImagePullBackOff   0          52m
```

**原因**：
- Registry 中不存在該映像
- Registry 連接問題

**解決方案**：
```bash
# 檢查 Registry 狀態
docker ps | grep kind-registry

# 檢查映像是否存在
curl http://localhost:5001/v2/podinfo/tags/list

# 重新構建並推送
make dev-local-release

# 重啟 Registry（如需要）
docker restart kind-registry
```

### 2. ArgoCD OutOfSync

**症狀**：
Application 顯示 OutOfSync 狀態

**原因**：
- Git 倉庫有未同步的變更
- 手動修改了叢集資源

**解決方案**：
```bash
# 檢查差異
kubectl get application podinfo-local -n argocd -o yaml | grep -A10 "status:"

# 手動同步
kubectl patch application podinfo-local -n argocd \
  --type merge -p '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {}}}'

# 強制同步（覆蓋本地變更）
argocd app sync podinfo-local --force
```

### 3. Pod 無法啟動 (CrashLoopBackOff)

**症狀**：
Pod 不斷重啟

**診斷**：
```bash
# 查看 Pod 狀態
kubectl describe pod -n demo-local <pod-name>

# 查看日誌
kubectl logs -n demo-local <pod-name> --previous

# 查看事件
kubectl get events -n demo-local --sort-by='.lastTimestamp'
```

**常見原因**：
- 應用配置錯誤
- 資源限制太低
- 健康檢查失敗

### 4. ServiceMonitor 不生效

**症狀**：
Prometheus 無法抓取 metrics

**檢查步驟**：
```bash
# 確認 CRD 存在
kubectl get crd servicemonitors.monitoring.coreos.com

# 檢查 ServiceMonitor
kubectl get servicemonitor -n demo-local

# 驗證標籤匹配
kubectl get svc -n demo-local --show-labels

# 查看 Prometheus 配置
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# 訪問 http://localhost:9090/config
```

### 5. 本地 Registry 網路問題

**症狀**：
無法推送映像到 localhost:5001

**解決方案**：
```bash
# 檢查網路連接
docker network inspect kind

# 重新連接 Registry
docker network disconnect kind kind-registry
docker network connect kind kind-registry

# 測試 Registry
make registry-test

# 從叢集內部測試
kubectl run test-registry --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://kind-registry:5000/v2/_catalog
```

## 調試技巧

### 1. 啟用詳細日誌

ArgoCD：
```bash
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --patch '{"data": {"application.instanceLabelKey": "debug"}}'
```

應用：
```bash
kubectl set env deployment/local-podinfo -n demo-local LOG_LEVEL=debug
```

### 2. 進入 Pod Shell

```bash
# 進入運行中的 Pod
kubectl exec -it -n demo-local <pod-name> -- sh

# 調試用臨時 Pod
kubectl run debug --image=busybox -n demo-local --rm -it -- sh
```

### 3. 檢查資源使用

```bash
# Pod 資源使用
kubectl top pods -n demo-local

# 節點資源
kubectl top nodes

# 詳細資源分配
kubectl describe node
```

### 4. 網路調試

```bash
# 測試服務連接
kubectl run test --image=nicolaka/netshoot --rm -it -- bash

# DNS 解析
nslookup local-podinfo.demo-local.svc.cluster.local

# 端口連接
nc -zv local-podinfo.demo-local 9898
```

## 重置環境

### 部分重置

```bash
# 刪除並重新部署應用
make delete-local
make deploy-local

# 重啟 ArgoCD
kubectl rollout restart deployment -n argocd

# 清理 Registry
docker exec kind-registry rm -rf /var/lib/registry/docker/registry/v2/repositories/podinfo
```

### 完全重置

```bash
# 清理所有應用
make clean-apps

# 重建叢集
make delete-cluster
make setup-cluster
make install-argocd
make deploy-apps
```

## 效能優化

### 1. Registry 快取

配置 Docker 使用本地快取：
```json
{
  "registry-mirrors": ["http://localhost:5001"]
}
```

### 2. 資源限制調整

編輯 deployment：
```yaml
resources:
  limits:
    memory: "512Mi"
    cpu: "500m"
  requests:
    memory: "256Mi"
    cpu: "250m"
```

### 3. 映像大小優化

使用多階段構建：
```dockerfile
FROM golang:1.20 AS builder
WORKDIR /app
COPY . .
RUN go build -o app

FROM alpine:latest
COPY --from=builder /app/app /app
CMD ["/app"]
```

## 取得協助

### 查看日誌

```bash
# ArgoCD 日誌
kubectl logs -n argocd deployment/argocd-server

# Ingress Controller 日誌
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# 應用日誌
kubectl logs -n demo-local -l app=podinfo --tail=100
```

### 收集診斷資訊

```bash
# 系統狀態
make status

# 詳細診斷
kubectl cluster-info dump --output-directory=/tmp/cluster-dump
```

## 相關文檔

- [設置指南](setup.md) - 環境設置
- [開發流程](development.md) - 開發工作流程
- [清理指南](../../operations/cleanup.md) - 資源清理
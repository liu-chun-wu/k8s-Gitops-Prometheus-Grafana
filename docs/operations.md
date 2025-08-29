# 運維操作指南

## ArgoCD 管理

### 訪問配置

#### Ingress 訪問設置
```bash
# 完整設置（含密碼）
make ingress

# 手動步驟
kubectl apply -f ingress/argocd/argocd-ingress.yaml
kubectl apply -f gitops/argocd/argocd-secret.yaml
```

#### 密碼管理
- 開發環境固定密碼：admin / admin123
- 生產環境建議：Sealed Secrets, External Secrets

### 應用管理

```bash
# 查看所有應用
kubectl get applications -n argocd

# 同步應用
argocd app sync podinfo-local

# 刪除應用
kubectl delete application podinfo-local -n argocd
```

## 監控系統

### Prometheus

#### 訪問方式
- Port-forward: `kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090`
- URL: http://localhost:9090

#### 常用查詢
```promql
# CPU 使用率
rate(container_cpu_usage_seconds_total[5m])

# 內存使用
container_memory_usage_bytes

# Pod 重啟次數
kube_pod_container_status_restarts_total
```

### Grafana

#### 訪問方式
- URL: http://localhost:3001
- 登入: admin / admin123

#### 推薦儀表板
- Kubernetes Cluster Overview (ID: 7249)
- Kubernetes Pod Overview (ID: 6417)
- Node Exporter Full (ID: 1860)

## 清理操作

### 快速清理
```bash
make clean  # 刪除整個叢集
```

### 選擇性清理

#### 刪除應用
```bash
kubectl delete applications --all -n argocd
```

#### 刪除命名空間
```bash
kubectl delete namespace demo-local demo-ghcr monitoring
```

#### 重置 ArgoCD
```bash
kubectl delete namespace argocd
make install-argocd
```

## 日常維護

### 健康檢查
```bash
# 叢集狀態
make status

# 詳細診斷
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl top nodes
kubectl top pods -A
```

### 日誌查看
```bash
# ArgoCD 日誌
make logs

# 應用日誌
kubectl logs -n demo-local -l app=podinfo --tail=100

# 監控日誌
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

### 備份與恢復

#### 備份 ArgoCD 應用
```bash
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml
```

#### 恢復應用
```bash
kubectl apply -f argocd-apps-backup.yaml
```

## 故障處理

### ArgoCD 無法同步
```bash
# 檢查應用狀態
kubectl get application podinfo-local -n argocd -o yaml

# 強制同步
kubectl patch application podinfo-local -n argocd --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Prometheus 無數據
```bash
# 檢查 ServiceMonitor
kubectl get servicemonitor -A

# 檢查 Prometheus 配置
kubectl get prometheus -n monitoring -o yaml
```

### Ingress 無法訪問
```bash
# 檢查 Ingress Controller
kubectl get pods -n ingress-nginx

# 檢查 Ingress 資源
kubectl get ingress -A

# 檢查 DNS
nslookup argocd.local
```

## 安全建議

1. **生產環境不使用固定密碼**
2. **啟用 RBAC**
3. **定期更新組件**
4. **監控審計日誌**
5. **使用 NetworkPolicy**
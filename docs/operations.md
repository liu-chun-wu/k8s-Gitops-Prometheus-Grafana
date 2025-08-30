# 運維手冊

## ArgoCD 管理

### 訪問配置
```bash
make ingress           # 設置 Ingress + 固定密碼
make access           # 查看訪問資訊
```

- **URL**: http://argocd.local
- **帳號**: admin / admin123

### 應用操作
```bash
# 查看應用
kubectl get applications -n argocd

# 同步應用  
argocd app sync podinfo-local

# 強制刷新
kubectl patch application podinfo-local -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## 監控系統

### Prometheus
- **URL**: http://localhost:9090
- **常用查詢**:
  - CPU: `rate(container_cpu_usage_seconds_total[5m])`
  - Memory: `container_memory_usage_bytes`
  - Restarts: `kube_pod_container_status_restarts_total`

### Grafana
- **URL**: http://localhost:3001  
- **帳號**: admin / admin123
- **推薦儀表板**: 7249, 6417, 1860

## 故障排除速查

| 問題 | 診斷命令 | 解決方案 |
|------|---------|----------|
| ArgoCD 無法訪問 | `kubectl get pods -n argocd` | `make ingress` |
| 應用 OutOfSync | `kubectl get app -n argocd` | `make dev` 或強制同步 |
| Prometheus 無數據 | `curl http://localhost:9090/targets` | 檢查 ServiceMonitor |
| Grafana 登入失敗 | `kubectl get svc -n monitoring` | 使用 admin/admin123 |
| Ingress 無法訪問 | `kubectl get ingress -A` | 檢查 /etc/hosts |
| Pod CrashLoop | `kubectl describe pod <name>` | 查看日誌找原因 |

## 日常維護

### 健康檢查
```bash
make status                            # 整體狀態
kubectl get pods -A | grep -v Running  # 問題 Pod
kubectl top nodes                      # 資源使用
```

### 日誌查看
```bash
make logs                                     # ArgoCD 日誌
kubectl logs -n demo-local -l app=podinfo    # 應用日誌
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus  # Prometheus
```

### 清理操作
```bash
make clean                    # 刪除整個叢集
kubectl delete apps --all -n argocd  # 只刪應用
kubectl delete ns demo-local demo-ghcr  # 刪命名空間
```

## 進階診斷

### 叢集問題
```bash
# 節點狀態
kubectl describe node

# Docker 重啟
docker restart gitops-demo-control-plane

# 重建叢集
make clean && make quickstart
```

### 網路問題
```bash
# 檢查 Service
kubectl get svc,ep -A

# 測試連接
kubectl exec -it <pod> -- curl <service>:<port>

# DNS 測試
kubectl exec -it <pod> -- nslookup <service>
```

### 存儲問題
```bash
# PV/PVC 狀態
kubectl get pv,pvc -A

# 清理未使用 PVC
kubectl delete pvc --all -n <namespace>
```

## 備份恢復

```bash
# 備份應用
kubectl get applications -n argocd -o yaml > backup.yaml

# 恢復應用
kubectl apply -f backup.yaml
```

## 安全建議

1. **生產環境**: 不使用固定密碼
2. **Secret 管理**: 使用 Sealed Secrets
3. **RBAC**: 啟用角色權限控制
4. **網路策略**: 限制 Pod 間通訊
5. **審計日誌**: 監控敏感操作
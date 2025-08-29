# 故障排除指南

## 常見問題速查表

| 問題 | 可能原因 | 解決方案 |
|------|---------|----------|
| ArgoCD 無法訪問 | Ingress 未安裝 | `make ingress` |
| | /etc/hosts 未配置 | 添加 `127.0.0.1 argocd.local` |
| | Pod 未就緒 | `kubectl get pods -n argocd` |
| Grafana 無法登入 | 密碼錯誤 | 使用 admin/admin123 |
| | Service 未就緒 | `kubectl get svc -n monitoring` |
| 應用未同步 | Git 權限問題 | 檢查 repo URL |
| | 網路問題 | `kubectl logs -n argocd deployment/argocd-repo-server` |
| Registry 推送失敗 | Registry 未啟動 | `docker ps \| grep registry` |
| | 網路配置錯誤 | `make test` |

## 詳細診斷步驟

### 1. Kind 叢集問題

#### 症狀：叢集無法創建
```bash
# 檢查 Docker
docker info

# 清理舊叢集
kind delete cluster --name gitops-demo
docker rm -f kind-registry

# 重新創建
make setup
```

#### 症狀：節點 NotReady
```bash
# 檢查節點
kubectl get nodes
kubectl describe node <node-name>

# 重啟 Docker
sudo systemctl restart docker  # Linux
# macOS: 重啟 Docker Desktop
```

### 2. ArgoCD 問題

#### 症狀：應用 OutOfSync
```bash
# 查看詳細狀態
kubectl get application podinfo-local -n argocd -o yaml

# 手動同步
kubectl patch application podinfo-local -n argocd --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# 檢查 Git 連接
kubectl logs -n argocd deployment/argocd-repo-server | grep error
```

#### 症狀：密碼無法登入
```bash
# 重置密碼
kubectl delete secret argocd-secret -n argocd
kubectl apply -f gitops/argocd/argocd-secret.yaml
kubectl rollout restart deployment argocd-server -n argocd
```

### 3. 監控問題

#### 症狀：Prometheus 無數據
```bash
# 檢查 targets
curl http://localhost:9090/targets

# 檢查 ServiceMonitor
kubectl get servicemonitor -A
kubectl describe servicemonitor podinfo-monitor -n monitoring

# 重新部署
kubectl delete application kube-prometheus-stack -n argocd
make deploy-monitoring
```

#### 症狀：Grafana 儀表板空白
```bash
# 檢查數據源
kubectl get cm -n monitoring | grep datasource

# 檢查 Prometheus 連接
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  wget -O- http://kube-prometheus-stack-prometheus:9090/api/v1/query?query=up
```

### 4. Ingress 問題

#### 症狀：無法通過域名訪問
```bash
# 檢查 Ingress Controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# 檢查 Ingress 資源
kubectl get ingress -A
kubectl describe ingress argocd-server-ingress -n argocd

# 測試連接
curl -H "Host: argocd.local" http://localhost
```

### 5. Registry 問題

#### 症狀：映像推送失敗
```bash
# 檢查 Registry
docker ps | grep registry
curl http://localhost:5001/v2/_catalog

# 測試推送
docker pull busybox
docker tag busybox localhost:5001/test:latest
docker push localhost:5001/test:latest

# 檢查網路
docker network ls
docker network inspect kind
```

## 調試命令集

### 快速診斷
```bash
# 一鍵檢查所有組件
make status

# 查看問題 Pod
kubectl get pods -A | grep -v Running

# 查看最近事件
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### 日誌收集
```bash
# ArgoCD 日誌
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100

# 應用日誌
kubectl logs -n demo-local -l app=podinfo --tail=100

# Ingress 日誌
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100
```

### 資源檢查
```bash
# CPU/內存使用
kubectl top nodes
kubectl top pods -A

# 存儲使用
kubectl get pv,pvc -A

# 網路檢查
kubectl get svc,ep,ingress -A
```

## 終極解決方案

如果以上方法都無法解決：

```bash
# 完全重置環境
make clean
make quickstart
make ingress

# 重新配置 hosts
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'
```

## 獲取幫助

- 查看 Makefile 幫助：`make help`
- 項目 Issues：https://github.com/your-repo/issues
- Kubernetes 文檔：https://kubernetes.io/docs/
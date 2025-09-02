# 監控預警系統測試計劃
_最後更新：2025-09-02_

## 📋 測試概覽

本測試計劃涵蓋 Prometheus + AlertManager + Discord 預警系統的完整驗證，包含 6 個測試階段，預計總時長 90 分鐘。

### 系統架構
```
Prometheus → AlertManager → alertmanager-discord → Discord Webhook
```

### 前置條件
- ✅ Kubernetes 集群運行中
- ✅ Prometheus Stack 已部署
- ✅ Discord Webhook 已配置
- ✅ Grafana Dashboards（15757-15762, 19105）已導入

## 🚀 快速開始

```bash
# 1. 確認環境變數
cat .env | grep DISCORD_WEBHOOK_URL

# 2. 安裝預警系統
make alert-install

# 3. 執行快速測試
make test-alert-instant

# 4. 檢查 Discord 頻道是否收到通知
```

## 📊 測試階段

### 第一階段：基礎連通性測試（5分鐘）

#### 1.1 立即觸發測試
```bash
# 部署立即觸發的測試警報
make test-alert-instant

# 監控警報狀態
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# 訪問 http://localhost:9090/alerts
```

**預期結果：**
- 0秒：收到 InstantTestAlert (info)
- 10秒：收到 TestAlertInfo10s (info)
- 30秒：收到 TestAlertWarning30s (warning)
- 60秒：收到 TimeBasedTestAlert (info)

#### 1.2 手動觸發 Critical 警報
```bash
kubectl edit prometheusrule test-instant-alert -n monitoring
# 修改 TestAlertCritical 的 expr: vector(1) > 0
```

### 第二階段：應用層警報測試（30分鐘）

#### 2.1 CPU 壓力測試
```bash
# 部署 CPU 壓力測試
kubectl run cpu-stress --image=alpine/stress-ng \
  --namespace=demo-ghcr \
  --restart=Never -- --cpu 2 --timeout 360s

# 監控 CPU 使用率
kubectl top pod -n demo-ghcr
```

**觸發條件：** CPU > 80% 持續 5 分鐘  
**警報名稱：** PodinfoHighCPUUsage (warning)

#### 2.2 記憶體壓力測試
```bash
# 部署記憶體壓力測試
kubectl run mem-stress --image=alpine/stress-ng \
  --namespace=demo-ghcr \
  --restart=Never -- --vm 1 --vm-bytes 200M --timeout 360s
```

**觸發條件：** Memory > 80% 持續 5 分鐘  
**警報名稱：** PodinfoHighMemoryUsage (warning)

#### 2.3 Pod 重啟測試
```bash
# 創建會持續崩潰的 Pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crash-test
  namespace: demo-ghcr
spec:
  containers:
  - name: crash
    image: busybox
    command: ["sh", "-c", "echo crash && exit 1"]
EOF

# 查看重啟次數
kubectl get pod crash-test -n demo-ghcr -w
```

**觸發條件：** 重啟率 > 0.1 次/分鐘 持續 5 分鐘  
**警報名稱：** PodinfoPodRestartingTooOften (critical)

#### 2.4 Pod 健康狀態測試
```bash
# 停止 ghcr-podinfo deployment
kubectl scale deployment ghcr-podinfo --replicas=0 -n demo-ghcr

# 等待 5 分鐘觸發警報
sleep 300

# 恢復
kubectl scale deployment ghcr-podinfo --replicas=2 -n demo-ghcr
```

**觸發條件：** Pod 非 Running 狀態持續 5 分鐘  
**警報名稱：** PodinfoPodNotHealthy (critical)

### 第三階段：HTTP 性能測試（20分鐘）

#### 3.1 負載測試（hey）
```bash
# 設置端口轉發
kubectl port-forward -n demo-ghcr svc/ghcr-podinfo 9898:9898 &

# 執行負載測試
hey -z 120s -c 50 -q 100 http://localhost:9898/

# 生成錯誤請求
hey -z 60s -c 20 http://localhost:9898/invalid-endpoint
```

**監控指標：**
- HTTP 5xx 錯誤率 > 5% → PodinfoHighErrorRate (warning)
- P95 延遲 > 1秒 → PodinfoHighLatency (warning)

#### 3.2 滾動更新測試
```bash
# 觸發滾動更新
kubectl set image deployment/ghcr-podinfo \
  podinfo=ghcr.io/stefanprodan/podinfo:latest \
  -n demo-ghcr

# 監控更新狀態
kubectl rollout status deployment/ghcr-podinfo -n demo-ghcr
```

**驗證點：** 服務保持可用，無 PodinfoServiceDown 警報

### 第四階段：基礎設施測試（15分鐘）

#### 4.1 節點故障模擬（Kind 環境）
```bash
# 獲取 worker 節點名稱
docker ps --filter name=kind-worker

# 停止節點
docker stop kind-worker

# 監控節點狀態
kubectl get nodes -w

# 恢復節點
docker start kind-worker
```

#### 4.2 服務端點測試
```bash
# 刪除服務
kubectl delete service ghcr-podinfo -n demo-ghcr

# 等待 2 分鐘觸發 PodinfoServiceDown

# 重建服務
kubectl expose deployment ghcr-podinfo \
  --port=9898 \
  --target-port=9898 \
  -n demo-ghcr
```

### 第五階段：警報管理測試（10分鐘）

#### 5.1 使用 AlertManager API 發送測試警報
```bash
# 端口轉發
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-alertmanager 9093:9093 &

# 發送合成警報
curl -XPOST http://localhost:9093/api/v2/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {
      "alertname": "SyntheticAlert",
      "severity": "warning",
      "service": "test"
    },
    "annotations": {
      "summary": "合成測試警報",
      "description": "通過 API 直接發送的測試警報"
    },
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%S)Z'",
    "endsAt": "'$(date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%S)Z'"
  }]'
```

#### 5.2 警報靜音測試
```bash
# 訪問 AlertManager UI
# http://localhost:9093/#/silences/new

# 創建靜音規則：
# - Matchers: alertname="TestAlertWarning30s"
# - Duration: 1 hour
```

### 第六階段：監控驗證（10分鐘）

#### 6.1 檢查 ServiceMonitor 和 Targets
```bash
# 查看 ServiceMonitor
kubectl get servicemonitors -n monitoring

# 檢查 Prometheus Targets
# http://localhost:9090/targets

# 驗證所有 targets 狀態為 UP
```

#### 6.2 Grafana Dashboard 驗證
```bash
# 端口轉發
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80

# 訪問 http://localhost:3000
# 預設帳號：admin / prom-operator
```

**檢查 Dashboards：**
- 15757: Kubernetes Views Global
- 15758: Kubernetes Views Namespaces
- 15759: Kubernetes Views Nodes
- 15760: Kubernetes Views Pods
- 19105: Prometheus AlertManager

## 🧪 測試命令速查

| 命令 | 說明 | 預計時間 |
|------|------|---------|
| `make alert-install` | 安裝預警系統 | 2分鐘 |
| `make test-alert-instant` | 立即觸發測試 | 1分鐘 |
| `make test-alert` | 延遲觸發測試 | 2分鐘 |
| `make clean-test-alerts` | 清理測試警報 | 30秒 |
| `make alert-status` | 檢查系統狀態 | 10秒 |
| `make alert-update-webhook` | 更新 webhook | 1分鐘 |

## 📝 警報規則總覽

### 生產環境警報（podinfo-alerts）

| 警報名稱 | 觸發條件 | 嚴重級別 | 持續時間 |
|---------|---------|---------|---------|
| PodinfoHighCPUUsage | CPU > 80% | warning | 5分鐘 |
| PodinfoHighMemoryUsage | Memory > 80% | warning | 5分鐘 |
| PodinfoPodRestartingTooOften | 重啟率 > 0.1/分鐘 | critical | 5分鐘 |
| PodinfoPodNotHealthy | Pod 非 Running | critical | 5分鐘 |
| PodinfoServiceDown | 服務不可用 | critical | 2分鐘 |
| PodinfoHighErrorRate | HTTP 5xx > 5% | warning | 5分鐘 |
| PodinfoHighLatency | P95 延遲 > 1秒 | warning | 5分鐘 |
| PodinfoDeploymentReplicasMismatch | 副本數不匹配 | warning | 10分鐘 |
| PodinfoPVCSpaceLow | PVC 可用 < 10% | warning | 5分鐘 |

### 測試警報觸發時間

| 測試類型 | 警報數量 | 觸發時間 |
|---------|---------|---------|
| test-alert-instant | 5個 | 0-60秒 |
| test-alert | 3個 | 1-2分鐘 |

## 🔧 故障排除

### Discord 未收到通知
```bash
# 1. 檢查 webhook secret
kubectl get secret alertmanager-discord-webhook -n monitoring -o yaml

# 2. 檢查 discord 服務日誌
kubectl logs -n monitoring deployment/alertmanager-discord

# 3. 測試網路連接
kubectl exec -it deployment/alertmanager-discord -n monitoring -- \
  curl -X POST $DISCORD_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"content":"Test message"}'
```

### 警報未觸發
```bash
# 1. 檢查規則是否載入
kubectl get prometheusrule -n monitoring

# 2. 檢查 Prometheus 配置
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# 訪問 http://localhost:9090/config

# 3. 驗證 PromQL 表達式
# 在 Prometheus UI Graph 頁面測試查詢
```

## ✅ 測試檢查清單

### 前置準備
- [ ] Discord Webhook URL 已配置
- [ ] 監控系統已部署（Prometheus + AlertManager）
- [ ] Grafana 可訪問
- [ ] kubectl 可連接集群

### 測試執行
- [ ] 基礎連通性測試完成
- [ ] CPU/記憶體壓力測試完成
- [ ] Pod 重啟和健康測試完成
- [ ] HTTP 性能測試完成
- [ ] 節點故障模擬完成
- [ ] 警報管理功能驗證完成

### 測試後清理
- [ ] 清理測試警報規則
- [ ] 刪除測試 Pods
- [ ] 停止端口轉發
- [ ] 記錄測試結果

## 📊 測試結果記錄表

| 測試項目 | 執行時間 | 結果 | 備註 |
|---------|---------|------|------|
| Discord 連通性 | | ⬜ Pass / ⬜ Fail | |
| CPU 壓力警報 | | ⬜ Pass / ⬜ Fail | |
| 記憶體壓力警報 | | ⬜ Pass / ⬜ Fail | |
| Pod 重啟警報 | | ⬜ Pass / ⬜ Fail | |
| 服務可用性警報 | | ⬜ Pass / ⬜ Fail | |
| HTTP 錯誤率警報 | | ⬜ Pass / ⬜ Fail | |
| HTTP 延遲警報 | | ⬜ Pass / ⬜ Fail | |
| 節點故障警報 | | ⬜ Pass / ⬜ Fail | |
| 警報路由功能 | | ⬜ Pass / ⬜ Fail | |
| 警報抑制功能 | | ⬜ Pass / ⬜ Fail | |

## 🎯 成功標準

- **功能性**：所有警報規則正確觸發和恢復
- **時效性**：警報在預定時間內觸發（±30秒）
- **準確性**：無誤報，無漏報
- **穩定性**：系統在壓力下保持穩定運行
- **可觀測性**：所有監控指標正常顯示

---
_測試完成後，執行 `make clean-test-alerts` 清理測試資源_
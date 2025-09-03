# Prometheus Metrics 分析與監控說明

## 概覽

本文件分析了目前 Kubernetes 集群中的 Prometheus 監控設置，包括 alert rules、metrics 類型說明，以及故障排除指南。

## 目前的監控架構

### 組件
- **Prometheus Server**: 收集和儲存 metrics
- **Alertmanager**: 處理告警通知
- **Grafana**: 視覺化儀表板
- **Node Exporter**: 節點級別 metrics
- **Kube State Metrics**: Kubernetes 資源狀態 metrics
- **cAdvisor**: 容器級別 metrics

### 服務端點
- Prometheus UI: `http://localhost:30090` (NodePort)
- Grafana UI: `http://localhost:30301` (NodePort)
- Alertmanager UI: `http://localhost:30093` (NodePort)

## Alert Rules 分析

### 1. CPU 使用率監控

```yaml
alert: PodinfoHighCPUUsage
expr: |
  (
    sum(rate(container_cpu_usage_seconds_total{namespace="demo-ghcr", pod=~"ghcr-podinfo-.*", container!=""}[5m])) by (pod)
    / 
    sum(container_spec_cpu_quota{namespace="demo-ghcr", pod=~"ghcr-podinfo-.*"}/container_spec_cpu_period{namespace="demo-ghcr", pod=~"ghcr-podinfo-.*"}) by (pod)
  ) * 100 > 80
```

**解釋:**
- `container_cpu_usage_seconds_total`: CPU 使用的累計秒數
- `rate()[5m]`: 計算 5 分鐘內的平均每秒增長率
- `container_spec_cpu_quota/container_spec_cpu_period`: CPU 限制 (requests/limits)
- 當 CPU 使用率超過 80% 持續 5 分鐘時觸發

### 2. 記憶體使用率監控

```yaml
alert: PodinfoHighMemoryUsage
expr: |
  (
    sum(container_memory_working_set_bytes{namespace="demo-ghcr", pod=~"ghcr-podinfo-.*", container!=""}) by (pod)
    /
    sum(container_spec_memory_limit_bytes{namespace="demo-ghcr", pod=~"ghcr-podinfo-.*", container!=""}) by (pod)
  ) * 100 > 80
```

**解釋:**
- `container_memory_working_set_bytes`: 容器實際使用的記憶體 (包含快取但排除可回收部分)
- `container_spec_memory_limit_bytes`: 容器的記憶體限制
- 當記憶體使用率超過 80% 時觸發

### 3. Pod 重啟監控

```yaml
alert: PodinfoPodRestartingTooOften
expr: |
  rate(kube_pod_container_status_restarts_total{namespace="demo-ghcr", pod=~"ghcr-podinfo-.*"}[15m]) > 0.1
```

**解釋:**
- `kube_pod_container_status_restarts_total`: Pod 重啟總次數
- `rate()[15m]`: 15 分鐘內的重啟頻率
- 當重啟頻率超過 0.1 次/秒 (即每 10 秒重啟一次) 時觸發

### 4. Pod 健康狀態監控

```yaml
alert: PodinfoPodNotHealthy
expr: |
  kube_pod_status_phase{namespace="demo-ghcr", pod=~"ghcr-podinfo-.*", phase!="Running"} > 0
```

**解釋:**
- `kube_pod_status_phase`: Pod 的當前階段狀態
- 可能的值: `Pending`, `Running`, `Succeeded`, `Failed`, `Unknown`
- 當 Pod 不是 `Running` 狀態超過 5 分鐘時觸發

### 5. 服務可用性監控

```yaml
alert: PodinfoServiceDown
expr: |
  up{job="ghcr-podinfo"} == 0
```

**解釋:**
- `up`: Prometheus 能否成功抓取目標的指標 (1=成功, 0=失敗)
- `job`: ServiceMonitor 中定義的任務標籤
- 當服務端點無法訪問超過 2 分鐘時觸發

### 6. HTTP 錯誤率監控

```yaml
alert: PodinfoHighErrorRate
expr: |
  (
    sum(rate(http_request_duration_seconds_count{namespace="demo-ghcr", status=~"5.."}[5m])) by (pod)
    /
    sum(rate(http_request_duration_seconds_count{namespace="demo-ghcr"}[5m])) by (pod)
  ) * 100 > 5
```

**解釋:**
- `http_request_duration_seconds_count`: HTTP 請求總數
- `status=~"5.."`: 正則表達式匹配 5xx 狀態碼
- 計算 5xx 錯誤率，當超過 5% 時觸發

### 7. HTTP 延遲監控

```yaml
alert: PodinfoHighLatency
expr: |
  histogram_quantile(0.95,
    sum(rate(http_request_duration_seconds_bucket{namespace="demo-ghcr"}[5m])) by (le, pod)
  ) > 1
```

**解釋:**
- `http_request_duration_seconds_bucket`: HTTP 請求延遲的直方圖桶
- `histogram_quantile(0.95, ...)`: 計算 95 分位數
- 當 95% 的請求延遲超過 1 秒時觸發

### 8. 部署副本數監控

```yaml
alert: PodinfoDeploymentReplicasMismatch
expr: |
  kube_deployment_spec_replicas{namespace="demo-ghcr", deployment="ghcr-podinfo"}
  !=
  kube_deployment_status_replicas_available{namespace="demo-ghcr", deployment="ghcr-podinfo"}
```

**解釋:**
- `kube_deployment_spec_replicas`: 期望的副本數
- `kube_deployment_status_replicas_available`: 實際可用的副本數
- 當期望與實際副本數不匹配超過 10 分鐘時觸發

### 9. 儲存空間監控

```yaml
alert: PodinfoPVCSpaceLow
expr: |
  (
    kubelet_volume_stats_available_bytes{namespace="demo-ghcr"}
    /
    kubelet_volume_stats_capacity_bytes{namespace="demo-ghcr"}
  ) * 100 < 10
```

**解釋:**
- `kubelet_volume_stats_available_bytes`: 可用儲存空間
- `kubelet_volume_stats_capacity_bytes`: 總儲存容量
- 當可用空間少於 10% 時觸發

## 關鍵 Metrics 類型說明

### Container Metrics (來自 cAdvisor)
- `container_cpu_usage_seconds_total`: CPU 使用累計時間
- `container_memory_working_set_bytes`: 實際記憶體使用量
- `container_spec_cpu_quota`: CPU 配額 (millicores)
- `container_spec_memory_limit_bytes`: 記憶體限制

### Kubernetes State Metrics
- `kube_pod_status_phase`: Pod 狀態
- `kube_pod_container_status_restarts_total`: 容器重啟次數
- `kube_deployment_spec_replicas`: 部署期望副本數
- `kube_deployment_status_replicas_available`: 可用副本數

### 應用 Metrics (來自 podinfo)
- `http_request_duration_seconds`: HTTP 請求延遲直方圖
- `http_request_duration_seconds_count`: HTTP 請求總數
- `up`: 目標是否可達

### Node Metrics
- `kubelet_volume_stats_available_bytes`: PV 可用空間
- `kubelet_volume_stats_capacity_bytes`: PV 總容量

## Alertmanager 配置

### 路由策略
1. **Critical**: 立即通知，每小時重複
2. **Warning**: 30秒延遲，每4小時重複
3. **Info**: 1分鐘延遲，每24小時重複

### 抑制規則
- Critical 警報會抑制同名的 warning 和 info 警報
- Warning 警報會抑制同名的 info 警報

### 通知渠道
- Discord webhook 整合
- 不同嚴重性使用不同的表情符號標識

## 故障排除指南

### 1. 檢查 Prometheus 目標狀態
```bash
# 查看所有目標
curl "http://localhost:30090/api/v1/targets"

# 查看特定 job 的目標
curl "http://localhost:30090/api/v1/targets?scrapePool=ghcr-podinfo"
```

### 2. 驗證 ServiceMonitor 配置
```bash
kubectl get servicemonitor -n demo-ghcr -o yaml
```

### 3. 檢查 Pod 標籤
```bash
kubectl get pods -n demo-ghcr --show-labels
```

### 4. 測試 metrics 端點
```bash
kubectl port-forward -n demo-ghcr svc/ghcr-podinfo 9898:9898
curl http://localhost:9898/metrics
```

### 5. 檢查 Prometheus 規則載入狀態
```bash
curl "http://localhost:30090/api/v1/rules"
```

### 6. 驗證警報狀態
```bash
curl "http://localhost:30090/api/v1/alerts"
```

## PromQL 查詢範例

### 基礎查詢
```promql
# 檢查服務是否運行
up{job="ghcr-podinfo"}

# CPU 使用率
rate(container_cpu_usage_seconds_total{pod=~"ghcr-podinfo-.*"}[5m])

# 記憶體使用量 (MB)
container_memory_working_set_bytes{pod=~"ghcr-podinfo-.*"} / 1024 / 1024
```

### 進階查詢
```promql
# HTTP 請求 QPS
sum(rate(http_request_duration_seconds_count[5m])) by (pod)

# 錯誤率
sum(rate(http_request_duration_seconds_count{status=~"5.."}[5m])) 
/ 
sum(rate(http_request_duration_seconds_count[5m])) * 100

# 延遲分位數
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

## 最佳實踐

1. **Alert 設計原則**
   - 設置適當的 `for` 持續時間避免假警報
   - 使用有意義的標籤進行分組
   - 提供清晰的 summary 和 description

2. **Metrics 收集**
   - 設置合理的 scrape 間隔 (15-30s)
   - 避免高基數標籤
   - 定期清理不需要的 metrics

3. **查詢優化**
   - 使用 `rate()` 而不是 `increase()` 計算速率
   - 善用 `by()` 和 `without()` 進行聚合
   - 避免過於複雜的查詢

## AlertmanagerFailedToSendAlerts 詳細分析

### Alert Rule 解析

```yaml
alert: AlertmanagerFailedToSendAlerts
expr: |
  (
    rate(alertmanager_notifications_failed_total{job="kube-prometheus-stack-alertmanager",namespace="monitoring"}[5m]) 
    / ignoring (reason) group_left () 
    rate(alertmanager_notifications_total{job="kube-prometheus-stack-alertmanager",namespace="monitoring"}[5m])
  ) > 0.01
for: 5m
labels:
  severity: warning
annotations:
  description: Alertmanager {{ $labels.namespace }}/{{ $labels.pod}} failed to send {{ $value | humanizePercentage }} of notifications to {{ $labels.integration }}.
  runbook_url: https://runbooks.prometheus-operator.dev/runbooks/alertmanager/alertmanagerfailedtosendalerts
  summary: An Alertmanager instance failed to send notifications.
```

### PromQL 查詢詳細解釋

**1. 基礎 Metrics**
- `alertmanager_notifications_total`: 總通知發送次數 (成功 + 失敗)
- `alertmanager_notifications_failed_total`: 失敗的通知發送次數

**2. Rate 計算**
```promql
rate(alertmanager_notifications_failed_total[5m])  # 每秒失敗率
rate(alertmanager_notifications_total[5m])         # 每秒總發送率
```

**3. 高級 PromQL 運算符**
- `ignoring (reason)`: 忽略 `reason` 標籤進行匹配
- `group_left ()`: 左側向量保持更多標籤信息
- 這是因為失敗 metrics 可能有額外的 `reason` 標籤 (如 DNS 錯誤、超時等)

**4. 閾值設定**
- `> 0.01`: 失敗率超過 1% 時觸發
- `for: 5m`: 持續 5 分鐘才發出警報

### 實際問題診斷

通過檢查 Alertmanager 日誌，發現的具體問題：

```
dial tcp: lookup alertmanager-discord on 10.96.0.10:53: no such host
```

**問題原因:**
1. `alertmanager-discord` 服務未部署
2. DNS 解析失敗
3. Alertmanager 配置中的 webhook URL 指向不存在的服務

**解決方案:**
1. 部署 `alertmanager-discord` 服務和 deployment
2. 確保服務名稱與配置中的一致
3. 驗證網路連接性

### 常見失敗原因與解決方法

#### 1. DNS 解析問題
**症狀:** `no such host` 錯誤
**解決:**
```bash
# 檢查服務是否存在
kubectl get svc -n monitoring alertmanager-discord

# 檢查 DNS 解析
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup alertmanager-discord.monitoring.svc.cluster.local
```

#### 2. 網路連接問題
**症狀:** `connection refused` 或 `timeout`
**解決:**
```bash
# 測試服務連接
kubectl run test-conn --image=curlimages/curl --rm -it --restart=Never -- curl -v http://alertmanager-discord.monitoring.svc.cluster.local:9094
```

#### 3. Webhook 配置錯誤
**症狀:** HTTP 4xx/5xx 錯誤
**解決:**
```bash
# 檢查 webhook 配置
kubectl get secret -n monitoring alertmanager-discord-webhook -o yaml

# 手動測試 Discord webhook
curl -X POST "YOUR_DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "Test message"}'
```

#### 4. 資源限制問題
**症狀:** `OOMKilled` 或 pod 重啟
**解決:**
```bash
# 檢查資源使用
kubectl top pod -n monitoring alertmanager-discord-*

# 查看 pod 事件
kubectl describe pod -n monitoring alertmanager-discord-*
```

### 監控和預防措施

#### 1. 設置額外的監控指標

```promql
# Discord 服務健康檢查
up{job="alertmanager-discord"}

# Alertmanager 連接測試
probe_success{job="alertmanager-webhook-probe"}
```

#### 2. 日誌監控配置

```yaml
# 在 Grafana 中創建日誌面板
{namespace="monitoring", pod=~"alertmanager-.*"} |= "failed" |= "notify"
```

#### 3. 定期健康檢查腳本

```bash
#!/bin/bash
# webhook-health-check.sh

# 測試 Discord webhook
curl -f -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "Health check from monitoring system"}' \
  || echo "Webhook health check failed"
```

### 最佳實踐建議

#### 1. Webhook 配置
```yaml
# 使用 HTTPS 和身份驗證
webhook_configs:
- url: 'https://secure-webhook.example.com/alerts'
  http_config:
    bearer_token: 'your-secure-token'
    tls_config:
      insecure_skip_verify: false
```

#### 2. 錯誤處理
```yaml
# 設置合理的超時和重試
webhook_configs:
- url: 'http://alertmanager-discord:9094'
  send_resolved: true
  http_config:
    bearer_token: 'optional-auth-token'
  max_alerts: 10  # 限制單次發送的警報數量
```

#### 3. 多渠道備用通知
```yaml
# 設置備用接收器
receivers:
- name: 'primary-notifications'
  webhook_configs:
  - url: 'http://alertmanager-discord:9094'
  email_configs:  # 備用郵件通知
  - to: 'alerts@company.com'
    subject: 'Backup Alert: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

## 參考資源

- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Kubernetes Monitoring with Prometheus](https://prometheus.io/docs/guides/kubernetes/)
- [Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [PromQL Functions](https://prometheus.io/docs/prometheus/latest/querying/functions/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Discord Webhooks API](https://discord.com/developers/docs/resources/webhook)
# 警報觸發條件完整說明

## 目錄
- [警報觸發原理](#警報觸發原理)
- [測試警報](#測試警報)
- [生產環境警報](#生產環境警報)
- [常見問題](#常見問題)

## 警報觸發原理

### 基本概念

每個 Prometheus 警報規則包含以下關鍵要素：

1. **expr (表達式)**: PromQL 查詢，返回布林值或向量
2. **for (持續時間)**: 條件必須持續為真的時間
3. **labels (標籤)**: 警報的元數據，用於路由和分組
4. **annotations (註解)**: 警報的描述性訊息

### 觸發流程

```
評估表達式 → 條件為真 → 等待 for 時間 → 發送警報
    ↑                                           ↓
    └──────── interval 週期 ←──────────────────┘
```

## 測試警報

### 立即觸發測試 (test-alert-instant.yaml)

| 警報名稱 | 觸發條件 | 延遲時間 | 用途 |
|---------|---------|---------|------|
| **InstantTestAlert** | `vector(1) > 0` | 0秒 | 立即驗證 Discord 連接 |
| **TestAlertInfo10s** | `vector(1) > 0` | 10秒 | 測試 info 級別路由 |
| **TestAlertWarning30s** | `vector(1) > 0` | 30秒 | 測試 warning 級別路由 |
| **TimeBasedTestAlert** | `hour() >= 0 and hour() <= 23` | 60秒 | 模擬真實時間條件 |
| **TestAlertCritical** | `vector(1) > 2` (預設關閉) | 0秒 | 手動測試 critical 級別 |

#### 使用方法

```bash
# 部署立即觸發的測試
make test-alert-instant

# 部署延遲觸發的測試 (1-2分鐘)
make test-alert

# 清理所有測試警報
make clean-test-alerts
```

#### 手動觸發 Critical 警報

```bash
# 編輯規則
kubectl edit prometheusrule test-instant-alert -n monitoring

# 修改 TestAlertCritical 的 expr:
# 從: expr: vector(1) > 2
# 改為: expr: vector(1) > 0
```

## 生產環境警報

### Podinfo 應用警報 (prometheus-rules.yaml)

| 警報名稱 | 觸發條件 | 嚴重級別 | 說明 |
|---------|---------|---------|------|
| **PodinfoHighCPUUsage** | CPU 使用率 > 80% | warning | 持續 5 分鐘 |
| **PodinfoHighMemoryUsage** | 記憶體使用率 > 80% | warning | 持續 5 分鐘 |
| **PodinfoPodRestartingTooOften** | 重啟率 > 0.1 次/分鐘 | critical | 持續 5 分鐘 |
| **PodinfoPodNotHealthy** | Pod 狀態非 Running | critical | 持續 5 分鐘 |
| **PodinfoServiceDown** | 服務端點無法存取 | critical | 持續 2 分鐘 |
| **PodinfoHighErrorRate** | HTTP 5xx 錯誤率 > 5% | warning | 持續 5 分鐘 |
| **PodinfoHighLatency** | 95分位延遲 > 1秒 | warning | 持續 5 分鐘 |
| **PodinfoDeploymentReplicasMismatch** | 副本數不匹配 | warning | 持續 10 分鐘 |
| **PodinfoPVCSpaceLow** | PVC 可用空間 < 10% | warning | 持續 5 分鐘 |

### 觸發條件詳解

#### CPU 使用率計算
```promql
(
  sum(rate(container_cpu_usage_seconds_total{namespace="podinfo"}[5m])) by (pod)
  / 
  sum(container_spec_cpu_quota/container_spec_cpu_period) by (pod)
) * 100 > 80
```
- 計算過去 5 分鐘的平均 CPU 使用率
- 與配置的 CPU 限制比較
- 超過 80% 並持續 5 分鐘觸發

#### 記憶體使用率計算
```promql
(
  sum(container_memory_working_set_bytes) by (pod)
  /
  sum(container_spec_memory_limit_bytes) by (pod)
) * 100 > 80
```
- 使用工作集記憶體（實際使用量）
- 與記憶體限制比較
- 超過 80% 並持續 5 分鐘觸發

#### Pod 重啟檢測
```promql
rate(kube_pod_container_status_restarts_total[15m]) > 0.1
```
- 計算 15 分鐘內的重啟率
- 超過 0.1 次/分鐘（約 1.5 次/15分鐘）觸發

## 警報管理

### 安裝和配置

```bash
# 首次安裝
cp .env.example .env
# 編輯 .env 設定 DISCORD_WEBHOOK_URL
make alert-install

# 更新 webhook
# 編輯 .env 更新 DISCORD_WEBHOOK_URL
make alert-update-webhook

# 完全重新安裝（更換 webhook）
# 編輯 .env 設定新的 DISCORD_WEBHOOK_URL
make alert-reinstall

# 檢查狀態
make alert-status

# 解除安裝
make alert-uninstall
```

### 警報路由配置

AlertManager 根據標籤路由警報到不同接收器：

```yaml
routes:
- match:
    severity: critical
  receiver: 'discord-critical'
  group_wait: 10s        # 首次等待時間
  repeat_interval: 1h    # 重複發送間隔

- match:
    severity: warning
  receiver: 'discord-warning'
  group_wait: 30s
  repeat_interval: 4h

- match:
    severity: info
  receiver: 'discord-info'
  group_wait: 1m
  repeat_interval: 24h
```

### 抑制規則

高優先級警報會抑制低優先級警報：

- Critical 警報抑制同一 namespace 的 warning 和 info
- Warning 警報抑制同一 namespace 的 info

## 常見問題

### Q1: 為什麼警報沒有立即觸發？

**原因**：
1. `for` 時間未到：條件必須持續為真達到指定時間
2. `interval` 評估週期：預設 30 秒評估一次
3. AlertManager 分組延遲：`group_wait` 時間

**解決方法**：
- 使用 `for: 0s` 立即觸發
- 減小 `interval` 評估週期
- 調整 AlertManager 的 `group_wait`

### Q2: 如何測試特定嚴重級別的警報？

```bash
# 測試 info 級別
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-specific-level
  namespace: monitoring
spec:
  groups:
  - name: test
    rules:
    - alert: TestSpecificLevel
      expr: vector(1) > 0
      for: 0s
      labels:
        severity: warning  # 改為需要測試的級別
        service: test
EOF
```

### Q3: 警報觸發但沒收到 Discord 通知？

檢查步驟：

1. **檢查 webhook URL**
   ```bash
   kubectl get secret alertmanager-discord-webhook -n monitoring -o yaml
   ```

2. **檢查 alertmanager-discord 服務**
   ```bash
   kubectl logs -n monitoring -l app=alertmanager-discord
   ```

3. **檢查 AlertManager 配置**
   ```bash
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
   # 訪問 http://localhost:9093/#/status
   ```

4. **驗證網路連接**
   ```bash
   kubectl exec -it deployment/alertmanager-discord -n monitoring -- \
     curl -X POST $DISCORD_WEBHOOK_URL \
     -H "Content-Type: application/json" \
     -d '{"content":"Test message"}'
   ```

### Q4: 如何調整警報敏感度？

修改觸發閾值和持續時間：

```yaml
# 降低敏感度（減少誤報）
- alert: HighCPU
  expr: cpu_usage > 90  # 提高閾值
  for: 10m              # 延長觀察時間

# 提高敏感度（快速響應）
- alert: ServiceDown
  expr: up == 0
  for: 30s              # 縮短觀察時間
```

### Q5: 如何暫時禁用特定警報？

```bash
# 方法 1: 刪除特定規則
kubectl delete prometheusrule <rule-name> -n monitoring

# 方法 2: 在 AlertManager UI 中靜音
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# 訪問 http://localhost:9093/#/silences/new

# 方法 3: 修改規則使其不會觸發
kubectl edit prometheusrule <rule-name> -n monitoring
# 將 expr 改為永遠為假的條件，如 vector(0) > 1
```

## 監控和調試

### 查看當前警報狀態

```bash
# Prometheus 警報狀態
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# 訪問 http://localhost:9090/alerts

# AlertManager 狀態
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# 訪問 http://localhost:9093
```

### 查看警報歷史

```bash
# 查看 AlertManager 日誌
kubectl logs -n monitoring deployment/kube-prometheus-stack-alertmanager

# 查看 Discord 轉發服務日誌
kubectl logs -n monitoring deployment/alertmanager-discord
```

### 驗證規則語法

```bash
# 使用 promtool（需要先安裝）
promtool check rules monitoring/alertmanager/prometheus-rules.yaml

# 或在 Prometheus UI 中測試表達式
# Graph → 輸入 PromQL 表達式 → Execute
```
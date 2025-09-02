# 預警系統設定指南

本文件說明如何設定和使用 Prometheus AlertManager 與 Discord 整合的預警通知系統。

## 📋 系統架構

```
Prometheus → AlertManager → alertmanager-discord → Discord Webhook
```

- **Prometheus**: 監控指標並觸發警報規則
- **AlertManager**: 管理警報路由、分組和抑制
- **alertmanager-discord**: 將 AlertManager 警報轉換為 Discord 訊息格式
- **Discord Webhook**: 接收並顯示警報訊息

## 🚀 快速開始

### 方法一：使用 .env 檔案（推薦本地開發）

1. **建立 Discord Webhook**：
   - 開啟 Discord，進入您要接收通知的頻道
   - 點擊頻道設定圖示（⚙️）→「整合」→「Webhook」
   - 建立新的 Webhook 並複製 URL

2. **設定環境變數**：
   ```bash
   # 複製 .env 範例檔案
   cp .env.example .env
   
   # 編輯 .env 檔案，填入您的 Discord Webhook URL
   # DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_TOKEN
   ```

3. **一鍵部署**：
   ```bash
   # 部署完整的警報系統
   make deploy-alerting
   
   # 測試 Discord 通知
   make test-alert
   
   # 測試完成後清理
   make clean-test-alerts
   ```

### 方法二：手動設定 Kubernetes Secret

```bash
# 直接建立 Secret
kubectl create secret generic alertmanager-discord-webhook \
  --from-literal=webhook-url='YOUR_DISCORD_WEBHOOK_URL' \
  --namespace=monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# 部署系統元件
kubectl apply -f monitoring/alertmanager/alertmanager-discord-secret.yaml
kubectl apply -f monitoring/alertmanager/prometheus-rules.yaml

# 測試警報
kubectl apply -f monitoring/alertmanager/test-alert.yaml
```

## 📊 警報規則說明

### Podinfo 應用警報

| 警報名稱 | 觸發條件 | 嚴重程度 | 說明 |
|---------|---------|---------|------|
| PodinfoHighCPUUsage | CPU > 80% 持續 5 分鐘 | warning | CPU 使用率過高 |
| PodinfoHighMemoryUsage | 記憶體 > 80% 持續 5 分鐘 | warning | 記憶體使用率過高 |
| PodinfoPodRestartingTooOften | 15分鐘內重啟率 > 0.1 | critical | Pod 頻繁重啟 |
| PodinfoPodNotHealthy | Pod 非 Running 狀態 5 分鐘 | critical | Pod 不健康 |
| PodinfoServiceDown | 服務端點無法存取 2 分鐘 | critical | 服務離線 |
| PodinfoHighErrorRate | HTTP 5xx 錯誤率 > 5% | warning | 錯誤率過高 |
| PodinfoHighLatency | 95分位延遲 > 1秒 | warning | 回應時間過長 |
| PodinfoDeploymentReplicasMismatch | 副本數不匹配 10 分鐘 | warning | 部署異常 |

### 警報嚴重程度

- **Critical** 🚨: 需要立即處理的嚴重問題
- **Warning** ⚠️: 需要關注但不緊急的問題  
- **Info** ℹ️: 一般資訊通知

## 💻 可用的 Make 命令

| 命令 | 說明 |
|------|------|
| `make setup-discord` | 從 .env 檔案設定 Discord Webhook |
| `make deploy-alerting` | 部署完整的警報系統（Discord + 規則） |
| `make test-alert` | 發送測試警報到 Discord |
| `make clean-test-alerts` | 清理測試警報規則 |

## 🔧 進階配置

### 自訂警報路由

編輯 `monitoring/kube-prometheus-stack/values.yaml` 中的 AlertManager 配置：

```yaml
alertmanager:
  config:
    route:
      routes:
      - match:
          severity: critical
        receiver: 'discord-critical'
        group_wait: 10s        # 首次等待時間
        repeat_interval: 1h    # 重複發送間隔
```

### 新增警報規則

建立新的 PrometheusRule 資源：

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-custom-alerts
  namespace: monitoring
spec:
  groups:
  - name: my.rules
    rules:
    - alert: MyCustomAlert
      expr: up{job="my-service"} == 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "服務離線"
        description: "{{ $labels.job }} 已離線超過 5 分鐘"
```

### 警報抑制規則

避免收到重複或次要警報：

```yaml
inhibit_rules:
- source_match:
    severity: 'critical'
  target_match_re:
    severity: 'warning|info'
  equal: ['alertname', 'namespace']
```

## 🔍 疑難排解

### 檢查警報狀態

```bash
# 查看 Prometheus 警報
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# 訪問 http://localhost:9090/alerts

# 查看 AlertManager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# 訪問 http://localhost:9093

# 檢查 Discord 轉發服務日誌
kubectl logs -n monitoring deployment/alertmanager-discord
```

### 常見問題

**Q: Discord 沒有收到通知**
- 檢查 Webhook URL 是否正確
- 確認 alertmanager-discord Pod 正在運行
- 查看 AlertManager 是否有觸發警報

**Q: 收到太多重複警報**
- 調整 `repeat_interval` 參數
- 設定適當的 `group_by` 規則
- 使用抑制規則過濾次要警報

**Q: 警報沒有觸發**
- 檢查 PrometheusRule 是否被載入
- 確認 PromQL 查詢語法正確
- 驗證 `for` 持續時間設定

## 📚 相關資源

- [Prometheus AlertManager 文件](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PrometheusRule CRD 規格](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#prometheusrule)
- [alertmanager-discord 專案](https://github.com/metalmatze/alertmanager-discord)
- [Discord Webhook 指南](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks)

## 🎯 最佳實踐

1. **分級警報**: 根據嚴重程度設定不同的通知頻道
2. **避免警報疲勞**: 只為真正需要關注的問題設定警報
3. **提供上下文**: 在警報描述中包含足夠的診斷資訊
4. **定期測試**: 定期執行測試警報確保系統正常運作
5. **文件化**: 為每個警報規則建立處理流程文件
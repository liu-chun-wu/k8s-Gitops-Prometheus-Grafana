#!/bin/bash

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函數：顯示訊息
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 檢查 .env 檔案是否存在
if [ ! -f ".env" ]; then
    log_error ".env 檔案不存在！"
    echo ""
    echo "請執行以下步驟："
    echo "1. cp .env.example .env"
    echo "2. 編輯 .env 檔案，填入您的 Discord Webhook URL"
    echo "3. 重新執行此腳本"
    exit 1
fi

# 載入 .env 檔案
source .env

# 檢查 DISCORD_WEBHOOK_URL 是否設定
if [ -z "$DISCORD_WEBHOOK_URL" ] || [ "$DISCORD_WEBHOOK_URL" == "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN" ]; then
    log_error "請在 .env 檔案中設定有效的 DISCORD_WEBHOOK_URL"
    echo ""
    echo "範例格式："
    echo "DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/1234567890/abcdefghijklmnop"
    exit 1
fi

# 驗證 URL 格式
if [[ ! "$DISCORD_WEBHOOK_URL" =~ ^https://discord(app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+$ ]]; then
    log_warning "Discord Webhook URL 格式可能不正確"
    echo "正確格式: https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN"
    read -p "是否要繼續？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log_info "Discord Webhook URL 已載入"

# 檢查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl 未安裝或不在 PATH 中"
    exit 1
fi

# 檢查是否連接到叢集
if ! kubectl cluster-info &> /dev/null; then
    log_error "無法連接到 Kubernetes 叢集"
    echo "請確保 Kind 叢集正在運行"
    exit 1
fi

# 建立 monitoring namespace（如果不存在）
if ! kubectl get namespace monitoring &> /dev/null; then
    log_info "建立 monitoring namespace..."
    kubectl create namespace monitoring
fi

# 建立或更新 Secret
log_info "建立/更新 Discord Webhook Secret..."
kubectl create secret generic alertmanager-discord-webhook \
    --from-literal=webhook-url="$DISCORD_WEBHOOK_URL" \
    --namespace=monitoring \
    --dry-run=client -o yaml | kubectl apply -f -

if [ $? -eq 0 ]; then
    log_success "Discord Webhook Secret 已成功建立/更新"
else
    log_error "建立 Secret 失敗"
    exit 1
fi

# 部署 alertmanager-discord 服務
log_info "部署 alertmanager-discord 服務..."
kubectl apply -f monitoring/alertmanager/alertmanager-discord-secret.yaml

# 等待 Pod 就緒
log_info "等待 alertmanager-discord Pod 就緒..."
kubectl wait --for=condition=ready pod -l app=alertmanager-discord -n monitoring --timeout=60s 2>/dev/null || {
    log_warning "Pod 尚未就緒，可能需要更多時間"
}

# 顯示 Pod 狀態
echo ""
log_info "alertmanager-discord Pod 狀態："
kubectl get pods -n monitoring -l app=alertmanager-discord

# 提供後續步驟
echo ""
echo "=================================="
log_success "Discord Webhook 設定完成！"
echo "=================================="
echo ""
echo "後續步驟："
echo "1. 部署警報規則："
echo "   kubectl apply -f monitoring/alertmanager/prometheus-rules.yaml"
echo ""
echo "2. 測試警報："
echo "   kubectl apply -f monitoring/alertmanager/test-alert-instant.yaml"
echo ""
echo "3. 檢查警報狀態："
echo "   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "   開啟 http://localhost:9090/alerts"
echo ""
echo "或直接執行: make test-alert"
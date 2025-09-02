#!/bin/bash

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# 顯示使用說明
show_usage() {
    echo "Usage: $0 {install|uninstall|update-webhook|reinstall|status}"
    echo ""
    echo "Commands:"
    echo "  install         - Install alerting system with Discord webhook"
    echo "  uninstall       - Completely remove alerting system"
    echo "  update-webhook  - Update Discord webhook URL only"
    echo "  reinstall       - Uninstall and reinstall (for webhook changes)"
    echo "  status          - Check alerting system status"
    exit 1
}

# 檢查必要工具
check_requirements() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# 載入 Discord webhook
load_webhook() {
    if [ ! -f ".env" ]; then
        log_error ".env file not found!"
        echo ""
        echo "Please run:"
        echo "1. cp .env.example .env"
        echo "2. Edit .env and add your Discord webhook URL"
        exit 1
    fi
    
    source .env
    
    if [ -z "$DISCORD_WEBHOOK_URL" ] || [ "$DISCORD_WEBHOOK_URL" == "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN" ]; then
        log_error "Please set valid DISCORD_WEBHOOK_URL in .env file"
        exit 1
    fi
    
    # 驗證 URL 格式
    if [[ ! "$DISCORD_WEBHOOK_URL" =~ ^https://discord(app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+$ ]]; then
        log_warning "Discord Webhook URL format might be incorrect"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_info "Discord Webhook URL loaded successfully"
}

# 安裝警報系統
install_alerts() {
    log_info "Installing alerting system..."
    
    # 確保 monitoring namespace 存在
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # 創建或更新 Discord webhook secret
    log_info "Creating Discord webhook secret..."
    kubectl create secret generic alertmanager-discord-webhook \
        --from-literal=webhook-url="$DISCORD_WEBHOOK_URL" \
        --namespace=monitoring \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # 部署 alertmanager-discord 服務
    log_info "Deploying alertmanager-discord service..."
    kubectl apply -f monitoring/alertmanager/alertmanager-discord-secret.yaml
    
    # 部署警報規則
    log_info "Deploying alert rules..."
    if [ -f "monitoring/alertmanager/prometheus-rules.yaml" ]; then
        kubectl apply -f monitoring/alertmanager/prometheus-rules.yaml
        log_success "Production alert rules deployed"
    fi
    
    # 等待 Pod 就緒
    log_info "Waiting for alertmanager-discord pod..."
    kubectl wait --for=condition=ready pod -l app=alertmanager-discord -n monitoring --timeout=60s 2>/dev/null || {
        log_warning "Pod may still be starting, checking status..."
        kubectl get pods -n monitoring -l app=alertmanager-discord
    }
    
    # 重啟 Prometheus 以載入新規則
    log_info "Reloading Prometheus configuration..."
    kubectl rollout restart statefulset prometheus-kube-prometheus-stack-prometheus -n monitoring 2>/dev/null || true
    
    log_success "Alerting system installed successfully!"
}

# 解除安裝警報系統
uninstall_alerts() {
    log_info "Uninstalling alerting system..."
    
    # 刪除測試警報（如果存在）
    kubectl delete prometheusrule test-discord-alert -n monitoring 2>/dev/null || true
    kubectl delete prometheusrule test-instant-alert -n monitoring 2>/dev/null || true
    
    # 刪除生產警報規則
    kubectl delete prometheusrule podinfo-alerts -n monitoring 2>/dev/null || true
    
    # 刪除 alertmanager-discord 服務
    kubectl delete deployment alertmanager-discord -n monitoring 2>/dev/null || true
    kubectl delete service alertmanager-discord -n monitoring 2>/dev/null || true
    
    # 刪除 Secret
    kubectl delete secret alertmanager-discord-webhook -n monitoring 2>/dev/null || true
    
    log_success "Alerting system uninstalled successfully!"
}

# 更新 webhook
update_webhook() {
    log_info "Updating Discord webhook..."
    
    # 更新 Secret
    kubectl create secret generic alertmanager-discord-webhook \
        --from-literal=webhook-url="$DISCORD_WEBHOOK_URL" \
        --namespace=monitoring \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # 重啟 alertmanager-discord pod
    kubectl rollout restart deployment alertmanager-discord -n monitoring
    
    # 等待 Pod 重啟
    log_info "Waiting for pod restart..."
    kubectl rollout status deployment alertmanager-discord -n monitoring --timeout=60s
    
    log_success "Discord webhook updated successfully!"
}

# 重新安裝
reinstall_alerts() {
    log_info "Reinstalling alerting system..."
    uninstall_alerts
    sleep 5
    install_alerts
    log_success "Alerting system reinstalled successfully!"
}

# 檢查狀態
check_status() {
    echo -e "${CYAN}=====================================${NC}"
    echo -e "${CYAN}     Alerting System Status${NC}"
    echo -e "${CYAN}=====================================${NC}"
    echo ""
    
    # 檢查 alertmanager-discord
    echo -e "${BLUE}Discord Webhook Service:${NC}"
    if kubectl get deployment alertmanager-discord -n monitoring &>/dev/null; then
        READY=$(kubectl get deployment alertmanager-discord -n monitoring -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        DESIRED=$(kubectl get deployment alertmanager-discord -n monitoring -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        # 確保變數是數字
        READY=${READY:-0}
        DESIRED=${DESIRED:-0}
        if [ "$READY" -eq "$DESIRED" ] && [ "$READY" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} alertmanager-discord: $READY/$DESIRED replicas ready"
        else
            echo -e "  ${YELLOW}⚠${NC} alertmanager-discord: $READY/$DESIRED replicas ready"
        fi
        
        # 顯示 Pod 狀態
        kubectl get pods -n monitoring -l app=alertmanager-discord --no-headers | while read pod rest; do
            STATUS=$(echo $rest | awk '{print $2}')
            READY_STATUS=$(echo $rest | awk '{print $1}')
            if [[ "$STATUS" == "Running" ]]; then
                echo -e "    Pod: $pod ${GREEN}[Running]${NC} $READY_STATUS"
            else
                echo -e "    Pod: $pod ${YELLOW}[$STATUS]${NC} $READY_STATUS"
            fi
        done
    else
        echo -e "  ${RED}✗${NC} alertmanager-discord not installed"
    fi
    
    echo ""
    echo -e "${BLUE}Alert Rules:${NC}"
    
    # 檢查警報規則
    RULES=$(kubectl get prometheusrule -n monitoring --no-headers 2>/dev/null | wc -l || echo 0)
    if [ "$RULES" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} $RULES PrometheusRules found"
        
        # 列出相關的警報規則
        kubectl get prometheusrule -n monitoring --no-headers 2>/dev/null | grep -E "(podinfo|test)" | while read rule rest; do
            echo -e "    • $rule"
        done
    else
        echo -e "  ${YELLOW}⚠${NC} No alert rules found"
    fi
    
    echo ""
    echo -e "${BLUE}Secret Status:${NC}"
    if kubectl get secret alertmanager-discord-webhook -n monitoring &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Discord webhook secret exists"
    else
        echo -e "  ${RED}✗${NC} Discord webhook secret not found"
    fi
    
    echo ""
    echo -e "${BLUE}AlertManager Configuration:${NC}"
    # 檢查 AlertManager 是否配置了 Discord receiver
    if kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring &>/dev/null; then
        CONFIG=$(kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d 2>/dev/null)
        if echo "$CONFIG" | grep -q "discord"; then
            echo -e "  ${GREEN}✓${NC} Discord receivers configured in AlertManager"
        else
            echo -e "  ${YELLOW}⚠${NC} Discord receivers not found in AlertManager config"
        fi
    else
        echo -e "  ${RED}✗${NC} AlertManager not found"
    fi
    
    echo ""
    echo -e "${CYAN}=====================================${NC}"
    echo ""
    echo "To test alerts, run: make test-alert-instant"
    echo "To view alerts: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
}

# 主程式
main() {
    check_requirements
    
    case "$1" in
        install)
            load_webhook
            install_alerts
            ;;
        uninstall)
            uninstall_alerts
            ;;
        update-webhook)
            load_webhook
            update_webhook
            ;;
        reinstall)
            load_webhook
            reinstall_alerts
            ;;
        status)
            check_status
            ;;
        *)
            show_usage
            ;;
    esac
}

# 執行主程式
main "$@"
# ArgoCD 訪問配置指南

本文檔說明如何配置 ArgoCD 的訪問方式，包括 Ingress 設置和密碼管理。

## 概述

ArgoCD 提供多種訪問方式：
- **Ingress 訪問**（推薦）：通過域名訪問，無需 port-forward
- **Port-forward 訪問**：臨時訪問，適合快速測試
- **LoadBalancer 訪問**：適用於雲環境

## Ingress 訪問配置

### 前置需求

1. **NGINX Ingress Controller**
2. **本地 DNS 配置**
3. **ArgoCD 服務運行正常**

### 配置步驟

#### 1. 安裝 NGINX Ingress Controller

```bash
# 使用 Makefile 命令
make install-ingress

# 或手動安裝（Kind 環境）
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 驗證安裝
kubectl get pods -n ingress-nginx
kubectl get ingressclass
```

#### 2. 配置 ArgoCD Ingress

##### 2.1 設置 ArgoCD 為 insecure 模式

創建或更新 ConfigMap：

```yaml
# ingress/argocd/argocd-cmd-params-cm-patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  server.insecure: "true"
```

應用配置：
```bash
kubectl apply -f ingress/argocd/argocd-cmd-params-cm-patch.yaml
kubectl rollout restart deployment argocd-server -n argocd
```

##### 2.2 創建 Ingress 資源

```yaml
# ingress/argocd/argocd-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```

應用 Ingress：
```bash
kubectl apply -f ingress/argocd/argocd-ingress.yaml
```

#### 3. 配置本地 DNS

添加 hosts 記錄：
```bash
# macOS/Linux
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'

# 驗證
ping argocd.local
```

## 密碼配置

### 開發環境固定密碼

為了方便開發測試，可以設置固定密碼：

#### 1. 創建 Secret 配置

```yaml
# gitops/argocd/argocd-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-secret
    app.kubernetes.io/part-of: argocd
type: Opaque
data:
  # admin password: admin123 (bcrypt hashed, base64 encoded)
  admin.password: JDJhJDEwJFBKaXhoSnlWNGNOYXRtM1ZxdzJPRXVGamxKSzVQV3NsRi5qRm9SMzQyU2FoQjg1c042eXdh
  admin.passwordMtime: MjAyNS0wMS0yOVQxMDowMDowMFo=
```

#### 2. 生成密碼 Hash

如需自定義密碼：
```bash
# 使用 htpasswd 生成 bcrypt hash
htpasswd -bnBC 10 "" yourpassword | tr -d ':\n' | sed 's/$2y/$2a/'

# 將結果進行 base64 編碼
echo -n 'your-bcrypt-hash' | base64
```

#### 3. 應用密碼配置

```bash
kubectl apply -f gitops/argocd/argocd-secret.yaml
kubectl rollout restart deployment argocd-server -n argocd
```

### 生產環境密碼管理

**重要**：生產環境不應使用固定密碼！

推薦方案：
- **Sealed Secrets**: 加密的 Secret 管理
- **External Secrets Operator**: 集成外部密鑰管理系統
- **HashiCorp Vault**: 企業級密鑰管理
- **AWS Secrets Manager / Azure Key Vault**: 雲原生方案

## 故障排除

### Ingress 無法訪問

1. **檢查 Ingress Controller**
```bash
kubectl get pods -n ingress-nginx
kubectl get ingress -n argocd
```

2. **檢查 DNS 配置**
```bash
cat /etc/hosts | grep argocd
curl -I http://argocd.local
```

3. **檢查 ArgoCD 服務**
```bash
kubectl get svc -n argocd
kubectl get pods -n argocd
```

### 密碼無法登入

1. **檢查 Secret 是否應用**
```bash
kubectl get secret argocd-secret -n argocd
```

2. **查看 ArgoCD Server 日誌**
```bash
kubectl logs -n argocd deployment/argocd-server
```

3. **重置為默認密碼**
```bash
# 刪除自定義 Secret
kubectl delete secret argocd-secret -n argocd

# 獲取初始密碼
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 安全建議

1. **開發環境**
   - 可使用固定密碼簡化開發
   - 確保不暴露到公網
   - 定期更新密碼

2. **生產環境**
   - 必須使用強密碼
   - 啟用 HTTPS/TLS
   - 配置 RBAC 和 SSO
   - 使用 Secret 管理工具
   - 啟用審計日誌

## 相關文檔

- [本地環境設置](../workflows/local/setup.md)
- [Ingress 配置](ingress.md)
- [安全最佳實踐](../reference/best-practices.md)
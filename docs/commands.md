# 命令速查

## 🚀 快速開始

| 命令 | 說明 |
|------|------|
| `make quickstart` | 互動式選擇部署模式 |
| `make quickstart-local` | 本地開發環境 |
| `make quickstart-ghcr` | GHCR 生產環境 |
| `make quickstart-both` | 完整環境 |
| `make access` | 顯示訪問資訊 |

## 🛠️ 環境設置

| 命令 | 說明 |
|------|------|
| `make setup-local` | 創建叢集 + Local Registry |
| `make setup-ghcr` | 創建叢集 (GHCR only) |
| `make install-argocd` | 安裝 ArgoCD |
| `make ingress` | 設置 Ingress |
| `make clean` | 刪除所有資源 |

## 🔧 開發部署

| 命令 | 說明 |
|------|------|
| `make dev` | 構建→推送→部署 |
| `make deploy` | 部署所有應用 |
| `make deploy-local` | 部署本地應用 |
| `make deploy-ghcr` | 部署 GHCR 應用 |
| `make deploy-monitoring` | 部署監控 |

## 📝 Git 操作

| 命令 | 說明 |
|------|------|
| `make update MSG="msg"` | sync + commit + push |
| `make commit MSG="msg"` | 提交變更 |
| `make sync` | 同步遠端 |
| `make push` | 推送變更 |

## 🔍 檢查狀態

| 命令 | 說明 |
|------|------|
| `make status` | 系統狀態 |
| `make logs` | ArgoCD 日誌 |
| `make test` | 測試 Registry |
| `make check-ghcr-access` | 檢查 GHCR 訪問 |

## 🌐 服務訪問

| 命令 | 說明 |
|------|------|
| `make forward` | Port-forward 所有服務 |
| `make port-forward-argocd` | ArgoCD (8080) |
| `make port-forward-grafana` | Grafana (3000) |
| `make port-forward-prometheus` | Prometheus (9090) |

## 💡 使用示例

### 完整設置
```bash
make quickstart
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'
make access
```

### 日常開發
```bash
make dev
make status
make update MSG="feat: new feature"
```

### 故障恢復
```bash
make status
make logs
make clean && make quickstart
```

## ⚙️ 環境變數

| 變數 | 預設值 |
|------|--------|
| `CLUSTER_NAME` | gitops-demo |
| `REGISTRY_PORT` | 5001 |
| `MSG` | "Update" |

## 📌 提示

- 輸入 `make` 查看所有命令
- 支援 Tab 自動補全
- 命令設計為冪等可重複執行
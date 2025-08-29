# Makefile 命令參考

所有可用的 Make 命令詳細說明。

## 查看幫助

```bash
make help
```

## 環境設置

| 命令 | 說明 | 使用場景 |
|------|------|----------|
| `make check-prereqs` | 檢查必要工具是否安裝 | 首次使用前 |
| `make quickstart` | 完整環境設置（叢集+ArgoCD+監控+應用） | 快速開始 |
| `make setup-cluster` | 創建 Kind 叢集與本地 Registry | 初始設置 |
| `make delete-cluster` | 刪除 Kind 叢集 | 重置環境 |

## ArgoCD 管理

| 命令 | 說明 | 使用場景 |
|------|------|----------|
| `make install-argocd` | 安裝 ArgoCD | 初始設置 |
| `make verify-argocd` | 驗證 ArgoCD 安裝 | 健康檢查 |
| `make get-passwords` | 獲取所有服務密碼 | 登入服務 |

## Ingress 設置

| 命令 | 說明 | 使用場景 |
|------|------|----------|
| `make install-ingress` | 安裝 NGINX Ingress Controller | 設置 Ingress |
| `make setup-argocd-ingress` | 配置 ArgoCD Ingress | 免 port-forward |
| `make setup-hosts` | 顯示 /etc/hosts 配置 | 配置域名 |

## 應用部署

| 命令 | 說明 | 使用場景 |
|------|------|----------|
| `make deploy-apps` | 部署所有應用 | 完整部署 |
| `make deploy-local` | 只部署本地版本 | 本地開發 |
| `make deploy-ghcr` | 只部署 GHCR 版本 | 生產部署 |
| `make delete-local` | 刪除本地應用 | 清理資源 |
| `make delete-ghcr` | 刪除 GHCR 應用 | 清理資源 |

## 本地開發

| 命令 | 說明 | 使用場景 |
|------|------|----------|
| `make dev-local-release` | 完整本地發布流程 | 快速迭代 |
| `make dev-local-build` | 構建本地映像 | 測試構建 |
| `make dev-local-push` | 推送到本地 Registry | 部署準備 |
| `make dev-local-update` | 更新 Kustomization | 版本更新 |
| `make dev-local-commit` | 提交並推送變更 | 觸發同步 |

## 監控系統

| 命令 | 說明 | 使用場景 |
|------|------|----------|
| `make deploy-monitoring` | 部署監控系統 | 初始設置 |
| `make verify-monitoring` | 驗證監控部署 | 健康檢查 |
| `make redeploy-monitoring` | 重新部署監控 | 更新配置 |
| `make setup-grafana-dashboards` | 導入 Grafana 儀表板 | 配置監控 |

## Port Forward

| 命令 | 說明 | 端口 |
|------|------|------|
| `make port-forward-all` | 轉發所有服務 | 見下方 |
| `make port-forward-argocd` | ArgoCD UI | 8081 |
| `make port-forward-grafana` | Grafana | 3001 |
| `make port-forward-prometheus` | Prometheus | 9090 |
| `make port-forward-podinfo-local` | 本地 PodInfo | 9898 |
| `make port-forward-podinfo-ghcr` | GHCR PodInfo | 9899 |

## Git 管理

| 命令 | 說明 | 使用方式 |
|------|------|----------|
| `make git-sync` | 同步遠端變更 | `make git-sync` |
| `make commit` | 提交變更 | `make commit MSG="message"` |
| `make push` | 推送到遠端 | `make push` |
| `make git-commit-push` | 一鍵提交並推送 | `make git-commit-push MSG="message"` |

## 狀態與調試

| 命令 | 說明 | 使用場景 |
|------|------|----------|
| `make status` | 顯示叢集和應用狀態 | 健康檢查 |
| `make verify-apps` | 驗證應用部署 | 部署檢查 |
| `make logs-argocd` | 查看 ArgoCD 日誌 | 故障排除 |
| `make registry-test` | 測試本地 Registry | 連接測試 |

## 清理操作

| 命令 | 說明 | 使用場景 |
|------|------|----------|
| `make clean-apps` | 刪除所有應用 | 清理應用 |
| `make clean` | 完全清理（刪除叢集） | 完全重置 |

## 使用技巧

### 查看命令幫助
每個命令都有簡短說明：
```bash
make help | grep deploy
```

### 命令組合
可以串聯多個命令：
```bash
make setup-cluster install-argocd deploy-apps
```

### 變數覆蓋
可以覆蓋預設變數：
```bash
make setup-cluster CLUSTER_NAME=my-cluster REGISTRY_PORT=5002
```

### 調試模式
查看實際執行的命令：
```bash
make -n dev-local-release
```

## 常用工作流程

### 初始設置
```bash
make quickstart
```

### 日常開發
```bash
# 本地開發
make dev-local-release

# 查看狀態
make status

# 查看日誌
kubectl logs -n demo-local -l app=podinfo
```

### 完全重置
```bash
make clean
make quickstart
```

## 環境變數

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `CLUSTER_NAME` | gitops-demo | Kind 叢集名稱 |
| `REGISTRY_PORT` | 5001 | 本地 Registry 端口 |
| `SHA` | git short hash | Git commit SHA |
| `TIMESTAMP` | 當前時間 | 時間戳記 |

## 相關文檔

- [本地開發流程](../workflows/local/development.md)
- [GHCR CI/CD](../workflows/ghcr/ci-cd.md)
- [故障排除](../workflows/local/troubleshooting.md)
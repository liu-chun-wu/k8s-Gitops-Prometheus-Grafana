# Makefile 命令參考

## 快速開始命令

| 命令 | 說明 | 用法 |
|------|------|------|
| `quickstart` | 完整環境設置（含 Ingress） | `make quickstart` |
| `setup` | 創建叢集和安裝 ArgoCD | `make setup` |
| `deploy` | 部署所有應用和監控 | `make deploy` |
| `access` | 顯示訪問資訊和密碼 | `make access` |
| `clean` | 刪除叢集和所有資源 | `make clean` |

## 開發命令

| 命令 | 說明 | 用法 |
|------|------|------|
| `dev` | 構建、推送、部署本地變更 | `make dev` |
| `sync` | 同步遠端倉庫 | `make sync` |
| `commit` | 提交所有變更 | `make commit MSG="your message"` |
| `push` | 推送到遠端 | `make push` |

## 服務訪問

| 命令 | 說明 | 用法 |
|------|------|------|
| `forward` | Port-forward 所有服務 | `make forward` |
| `ingress` | 設置 Ingress 和固定密碼 | `make ingress` |
| `passwords` | 顯示所有服務密碼 | `make passwords` |

## 運維命令

| 命令 | 說明 | 用法 |
|------|------|------|
| `status` | 顯示叢集和應用狀態 | `make status` |
| `logs` | 查看 ArgoCD 日誌 | `make logs` |
| `test` | 測試本地 Registry | `make test` |

## 個別組件命令

| 命令 | 說明 | 用法 |
|------|------|------|
| `install-argocd` | 只安裝 ArgoCD | `make install-argocd` |
| `deploy-local` | 只部署本地應用 | `make deploy-local` |
| `deploy-ghcr` | 只部署 GHCR 應用 | `make deploy-ghcr` |
| `deploy-monitoring` | 只部署監控系統 | `make deploy-monitoring` |

## 使用範例

### 完整設置流程
```bash
# 1. 從零開始設置
make quickstart

# 2. 配置本地 DNS
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'

# 3. 查看訪問資訊
make access
```

### 日常開發流程
```bash
# 1. 修改代碼
vim Dockerfile

# 2. 部署變更
make dev

# 3. 檢查狀態
make status
```

### Git 工作流程
```bash
# 提交並推送
make commit MSG="feat: add new feature"

# 或分開執行
make sync          # 拉取最新
make commit MSG="fix: bug fix"
make push          # 推送變更
```

### 故障排除流程
```bash
# 1. 檢查狀態
make status

# 2. 查看日誌
make logs

# 3. 測試連接
make test

# 4. 如需重置
make clean
make quickstart
```

## 環境變數

| 變數 | 預設值 | 說明 |
|------|--------|------|
| `CLUSTER_NAME` | gitops-demo | Kind 叢集名稱 |
| `REGISTRY_PORT` | 5001 | 本地 Registry 端口 |
| `MSG` | "Update" | Git commit 訊息 |

### 自定義範例
```bash
# 使用不同的叢集名稱
CLUSTER_NAME=my-cluster make setup

# 使用不同的 Registry 端口
REGISTRY_PORT=5002 make dev

# 自定義提交訊息
make commit MSG="feat: implement user authentication"
```

## 提示與技巧

1. **查看幫助**: `make help` 或只輸入 `make`
2. **彩色輸出**: Makefile 支援彩色輸出便於閱讀
3. **並行執行**: Port-forward 命令在背景執行
4. **錯誤處理**: 大部分命令包含錯誤處理和重試邏輯
5. **冪等性**: 所有命令設計為可重複執行

## 常用組合

```bash
# 完整重新部署
make clean quickstart

# 更新並檢查
make dev status

# 提交並同步
make commit MSG="update" push
```
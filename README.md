# K8s GitOps Demo with Prometheus & Grafana

一個完整的 GitOps 示範專案，展示如何使用 Kubernetes、ArgoCD、Prometheus 和 Grafana 建立現代化的雲原生應用部署與監控系統。

## 📋 前置需求

- Docker Desktop / Docker Engine
- Kind (Kubernetes in Docker)
- kubectl
- make
- git

安裝工具（macOS）：
```bash
brew install kind kubectl git
```

## 🚀 快速開始

### 選擇部署模式

```bash
# 方式一：互動式選擇（推薦）
make quickstart
# 系統會提示選擇：
# 1) Local - 本地開發（含 local registry）
# 2) GHCR - 生產環境（使用 GitHub Container Registry）
# 3) Both - 完整環境（同時支援兩種模式）

# 方式二：直接指定模式
make quickstart-local  # 本地開發環境
make quickstart-ghcr   # GHCR 生產環境
make quickstart-both   # 完整環境

# 配置本地 DNS
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'

# 查看訪問資訊
make access
```

**訪問服務：**
- ArgoCD: http://argocd.local (admin/admin123)
- Grafana: http://localhost:3001 (admin/admin123)
- Prometheus: http://localhost:9090

## 📚 文檔

- [快速開始](docs/getting-started.md) - 環境設置與快速上手
- [本地開發](docs/local-development.md) - 開發流程與 Git 工作流
- [運維操作](docs/operations.md) - ArgoCD、監控、清理操作
- [故障排除](docs/troubleshooting.md) - 常見問題與解決方案
- [命令參考](docs/command-reference.md) - 完整 Makefile 命令說明

## ⚠️ 安全提示

**重要**：本專案為開發/測試環境配置了固定密碼，請勿在生產環境使用！
- ArgoCD 默認密碼：admin / admin123
- Grafana 默認密碼：admin / admin123
- 生產環境請使用 Secret 管理工具（如 Sealed Secrets, External Secrets）

## ✨ 核心特性

- **靈活的部署模式**：
  - **Local Mode**：使用本地 registry (localhost:5001)，適合離線開發
  - **GHCR Mode**：使用 GitHub Container Registry，適合生產環境
    - 支援公開映像（無需認證）
    - 支援私有映像（需設置 secret）
  - **Both Mode**：同時支援兩種模式，最大靈活性
- **智慧環境設置**：根據選擇的模式自動配置對應的基礎設施
- **完整 GitOps**：ArgoCD 自動同步，Git 作為唯一真實來源
- **內建監控**：Prometheus + Grafana + ServiceMonitor
- **Ingress 訪問**：NGINX Ingress Controller，無需 Port Forward
- **固定密碼管理**：開發環境預配置密碼，簡化測試流程
- **一鍵操作**：豐富的 Makefile 命令
- **完整文檔**：詳細的設置和操作指南

## 🏗️ 專案結構

```
.
├── clusters/          # Kind 叢集配置
├── gitops/           # ArgoCD 應用定義
├── k8s/              # Kubernetes 資源
│   └── podinfo/      # 示範應用
│       ├── base/     # 基礎資源
│       └── overlays/ # 環境覆寫
├── monitoring/       # 監控系統配置
├── ingress/          # Ingress 資源
└── docs/            # 完整文檔
```

## 🛠️ 常用命令

| 命令 | 說明 |
|------|------|
| `make quickstart` | 🚀 互動式選擇部署模式 |
| `make quickstart-local` | 🏠 本地開發環境（含 registry） |
| `make quickstart-ghcr` | ☁️ GHCR 生產環境 |
| `make quickstart-both` | 🔄 完整環境（local + GHCR） |
| `make setup-local` | 📦 創建叢集（含 local registry） |
| `make setup-ghcr` | 📦 創建叢集（僅 GHCR） |
| `make deploy` | 🚢 部署所有應用 |
| `make dev` | 🔧 本地開發發布 |
| `make update MSG="msg"` | 🚀 完整 Git 工作流程 |
| `make commit MSG="msg"` | 💾 提交變更 |
| `make forward` | 🔌 Port-forward 服務 |
| `make ingress` | 🌍 設置 Ingress 訪問 |
| `make status` | 📊 查看系統狀態 |
| `make clean` | 🧹 清理所有資源 |

輸入 `make` 查看完整命令列表（含分組和彩色輸出）

## 🔧 開發流程

### 本地開發模式
```bash
# 使用本地 registry (需先執行 make setup-local)
# 1. 修改代碼
vim Dockerfile

# 2. 一鍵構建、推送、部署
make dev  # 自動推送到 localhost:5001
```

### GHCR 生產模式
```bash
# 使用 GitHub Container Registry (需先執行 make setup-ghcr)
# 1. 修改代碼並推送到 GitHub
# 2. CI/CD 自動構建並推送映像到 GHCR
# 3. ArgoCD 自動同步部署

# 檢查 GHCR 映像是否公開
make check-ghcr-access

# 如果使用私有映像，設置認證
make setup-ghcr-secret

# 3. 提交並推送所有變更（整合 Git 工作流程）
make update MSG="feat: add new feature"
```

## 🌐 服務訪問方式

### Ingress 訪問（推薦）
- **ArgoCD**: http://argocd.local (需配置 /etc/hosts)
- **Grafana**: http://localhost:3001
- **Prometheus**: http://localhost:9090

### Port Forward 訪問（備選）
```bash
make port-forward-all
```
- **ArgoCD**: http://localhost:8080
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090

## 📊 監控面板

- **Grafana**: 預配置的 Kubernetes 儀表板
- **Prometheus**: 指標收集與查詢
- **ServiceMonitor**: 自動服務發現與監控
- **AlertManager**: 告警管理（可選）

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

## 📄 授權

MIT License

---

**快速連結**：[開始使用](docs/getting-started.md) | [本地開發](docs/local-development.md) | [運維操作](docs/operations.md) | [故障排除](docs/troubleshooting.md) | [命令參考](docs/command-reference.md)
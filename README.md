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

```bash
# 1. 一鍵設置完整環境（約 5 分鐘）
make quickstart

# 2. 配置本地 DNS
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'

# 3. 查看訪問資訊
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

- **雙 Registry 支援**：本地開發（localhost:5001）+ 生產環境（GHCR）
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
| `make quickstart` | 🚀 完整環境設置（含 Ingress） |
| `make setup` | 📦 創建叢集和 ArgoCD |
| `make deploy` | 🚢 部署所有應用 |
| `make dev` | 🔧 本地開發發布 |
| `make commit MSG="msg"` | 💾 提交變更 |
| `make forward` | 🔌 Port-forward 服務 |
| `make ingress` | 🌍 設置 Ingress 訪問 |
| `make status` | 📊 查看系統狀態 |
| `make clean` | 🧹 清理所有資源 |

輸入 `make` 查看完整命令列表（含分組和彩色輸出）

## 🔧 開發流程

```bash
# 1. 修改代碼
vim Dockerfile

# 2. 一鍵構建、推送、部署
make dev

# 3. 提交變更
make commit MSG="feat: add new feature"
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
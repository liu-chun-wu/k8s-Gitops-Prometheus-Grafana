# K8s GitOps Demo with Prometheus & Grafana

一個完整的 GitOps 示範專案，展示如何使用 Kubernetes、ArgoCD、Prometheus 和 Grafana 建立現代化的雲原生應用部署與監控系統。

## 🚀 快速開始

```bash
# 1. 檢查環境
make check-prereqs

# 2. 一鍵設置完整環境（約 5 分鐘）
make quickstart

# 3. 訪問服務
# ArgoCD: http://argocd.local (admin/admin123) - 需要配置 /etc/hosts
# Grafana: http://localhost:3001 (admin/admin123)
# Prometheus: http://localhost:9090
```

## 📚 文檔結構

### 入門指南
- [前置需求](docs/getting-started/prerequisites.md) - 環境準備
- [快速開始](docs/getting-started/quickstart.md) - 5 分鐘上手
- [系統架構](docs/getting-started/architecture.md) - 架構說明

### 開發工作流程

#### 本地開發（推薦新手）
- [環境設置](docs/workflows/local/setup.md) - 設置 Kind + 本地 Registry
- [開發流程](docs/workflows/local/development.md) - 快速迭代開發
- [故障排除](docs/workflows/local/troubleshooting.md) - 常見問題解決

#### GHCR/生產環境
- [GHCR 設置](docs/workflows/ghcr/setup.md) - GitHub Container Registry 配置
- [CI/CD 流程](docs/workflows/ghcr/ci-cd.md) - GitHub Actions 自動化
- [故障排除](docs/workflows/ghcr/troubleshooting.md) - CI/CD 問題解決

### 運維操作
- [監控系統](docs/operations/monitoring.md) - Prometheus + Grafana
- [Ingress 配置](docs/operations/ingress.md) - 免 Port-forward 訪問
- [清理指南](docs/operations/cleanup.md) - 資源清理
- [維護操作](docs/operations/maintenance.md) - 日常維護

### 參考資料
- [Makefile 命令](docs/reference/makefile-commands.md) - 所有可用命令
- [目錄結構](docs/reference/directory-structure.md) - 專案結構說明
- [最佳實踐](docs/reference/best-practices.md) - GitOps 最佳實踐

## ⚠️ 安全提示

**重要**：本專案為開發/測試環境配置了固定密碼，請勿在生產環境使用！
- ArgoCD 默認密碼：admin / admin123
- Grafana 默認密碼：admin / admin123
- 生產環境請使用 Secret 管理工具（如 Sealed Secrets, External Secrets）

## ✨ 核心特性

- **雙 Registry 支援**：本地開發（localhost:5001）+ 生產環境（GHCR）
- **完整 GitOps**：ArgoCD 自動同步，Git 作為唯一真實來源
- **內建監控**：Prometheus + Grafana + ServiceMonitor
- **零配置 Ingress**：預配置好的 Ingress 規則
- **一鍵操作**：豐富的 Makefile 命令

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
| `make quickstart` | 完整環境設置 |
| `make dev-local-release` | 本地開發發布 |
| `make deploy-local` | 部署本地版本 |
| `make deploy-ghcr` | 部署 GHCR 版本 |
| `make status` | 查看系統狀態 |
| `make clean` | 清理所有資源 |

查看所有命令：`make help`

## 🔧 開發流程

### 本地開發（快速迭代）
```bash
# 1. 修改代碼
# 2. 一鍵發布
make dev-local-release
# 3. 自動同步到叢集
```

### 生產部署（自動化）
```bash
# 1. Push 到 main 分支
git push origin main
# 2. GitHub Actions 自動構建並部署
# 3. ArgoCD 自動同步
```

## 📊 監控面板

- **Grafana**: 預配置的 Kubernetes 儀表板
- **Prometheus**: 指標收集與查詢
- **AlertManager**: 告警管理（可選）

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

## 📄 授權

MIT License

---

**快速連結**：[本地開發](docs/workflows/local/setup.md) | [GHCR 部署](docs/workflows/ghcr/setup.md) | [問題排除](docs/workflows/local/troubleshooting.md) | [Makefile 命令](docs/reference/makefile-commands.md)
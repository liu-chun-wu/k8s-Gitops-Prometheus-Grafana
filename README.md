# K8s GitOps Demo with Prometheus & Grafana

使用 Kubernetes、ArgoCD、Prometheus 和 Grafana 建立現代化的雲原生應用部署與監控系統。

## 🚀 快速開始

```bash
# 1. 選擇部署模式
make quickstart        # 互動式選擇
make quickstart-local  # 本地開發環境
make quickstart-ghcr   # GHCR 生產環境

# 2. 配置本地 DNS
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'

# 3. 查看訪問資訊
make access
```

## 🌐 服務訪問

| 服務 | URL | 帳號密碼 |
|------|-----|----------|
| ArgoCD | http://argocd.local | admin/admin123 |
| Grafana | http://localhost:3001 | admin/admin123 |
| Prometheus | http://localhost:9090 | - |

## ✨ 核心特性

- **雙模式部署**：本地開發 (Local Registry) / 生產環境 (GHCR)
- **完整 GitOps**：ArgoCD 自動同步，Git 作為唯一真實來源
- **內建監控**：Prometheus + Grafana + ServiceMonitor
- **一鍵操作**：豐富的 Makefile 命令

## 📚 文檔

- [本地開發指南](docs/local.md) - 本地環境設置與開發流程
- [GHCR 部署指南](docs/ghcr.md) - GitHub Container Registry 配置
- [運維手冊](docs/operations.md) - ArgoCD、監控、故障排除
- [命令速查](docs/commands.md) - Makefile 命令參考

## 🏗️ 專案結構

```
├── clusters/          # Kind 叢集配置
├── gitops/           # ArgoCD 應用定義
├── k8s/              # Kubernetes 資源
│   └── podinfo/      # 示範應用
├── monitoring/       # 監控系統配置
└── ingress/          # Ingress 資源
```

## ⚠️ 安全提示

本專案為開發環境配置了固定密碼，**請勿在生產環境使用**！  
生產環境請使用 Secret 管理工具（如 Sealed Secrets）。

## 📄 授權

MIT License
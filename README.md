# K8s GitOps + Prometheus + Grafana 示範專案

一個完整的 GitOps 示範專案，使用 Kubernetes、ArgoCD、Prometheus 和 Grafana，同時支援本地開發與雲端 CI/CD 工作流程。

## 🚀 快速開始

```bash
# 檢查先決條件
make check-prereqs

# 完整設定（5 分鐘）
make quickstart

# 存取服務
make port-forward-all
```

**服務存取點：**
- ArgoCD: http://localhost:8080 (admin 密碼從叢集取得)
- Grafana: http://localhost:3000 (admin/admin123!@#)
- Prometheus: http://localhost:9090

## ✨ 功能特色

- **雙 Registry 支援**：本地 registry (localhost:5001) + GitHub Container Registry (GHCR)
- **GitOps 工作流程**：ArgoCD 以 Git 作為唯一真相來源管理部署
- **完整監控系統**：Prometheus + Grafana + AlertManager 技術堆疊
- **快速迭代開發**：本地開發環境具備自動映像建置與部署
- **CI/CD Pipeline**：GitHub Actions 自動建置與部署
- **正式環境就緒**：包含監控、日誌與安全最佳實務

## 📁 專案結構

```
k8s-gitops-prometheus-grafana/
├── clusters/kind/           # Kind 叢集設定檔
├── gitops/argocd/          # ArgoCD 應用程式
├── k8s/podinfo/            # Kustomize base + overlays
├── monitoring/             # Prometheus/Grafana 設定檔
├── .github/workflows/      # CI/CD pipelines
└── Makefile               # 自動化指令
```

## 🔄 開發工作流程

### 本地開發（快速迭代）
```bash
# 修改程式碼
make dev-local-release      # 建置 → 推送 → 更新 → 提交 → ArgoCD 同步
```

### 雲端 CI/CD（正式環境）
```bash
git push origin main        # 觸發 GitHub Actions → GHCR → Git 更新 → ArgoCD 同步
```

## 📊 監控系統

- **Prometheus**：指標收集，30 天保留期限
- **Grafana**：視覺化儀表板，含自定義 podinfo 指標
- **AlertManager**：告警路由與管理
- **ServiceMonitor**：自動指標發現

## 🛠️ 可用指令

```bash
make help                   # 顯示所有可用指令
make setup-cluster         # 建立 kind 叢集與 registry
make install-argocd        # 安裝 ArgoCD
make deploy-apps           # 部署應用程式
make deploy-monitoring     # 部署監控技術堆疊
make dev-local-release     # 本地開發發布
make port-forward-all      # 存取所有服務
make status               # 顯示叢集狀態
make clean                # 完整清理
```

## 📚 文件

- [快速開始指南](docs/QUICKSTART.md)
- [開發指南](k8s-gitops-prometheus-grafana-DEV.md)

## 🔧 先決條件

- Docker
- kind
- kubectl
- helm
- yq
- git

## 🏗️ 架構說明

此專案示範了完整的 GitOps 工作流程：

1. **本地開發**：使用 kind + 本地 registry 實現快速迭代
2. **基於 Git 的部署**：所有變更都在 Git 中追蹤
3. **自動化同步**：ArgoCD 監控 Git 並同步叢集狀態
4. **完整監控系統**：全方位可觀測性技術堆疊
5. **CI/CD 整合**：自動化建置與部署

非常適合學習 Kubernetes、GitOps 以及現代 DevOps 實務！
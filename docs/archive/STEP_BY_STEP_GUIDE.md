# K8s GitOps + Prometheus + Grafana 逐步操作指南

這份文件記錄了完整的 GitOps 環境建置過程，包含每個指令的詳細說明與作用。

## 📋 目錄

1. [環境檢查階段](#1-環境檢查階段)
2. [Kind 叢集建立階段](#2-kind-叢集建立階段)
3. [ArgoCD 安裝與配置階段](#3-argocd-安裝與配置階段)
4. [本地開發工作流程階段](#4-本地開發工作流程階段)
5. [應用部署階段](#5-應用部署階段)
6. [監控系統部署階段](#6-監控系統部署階段)
7. [最終驗證階段](#7-最終驗證階段)

---

## 1. 環境檢查階段

### 1.1 檢查先決條件

```bash
make check-prereqs
```

**作用：**
- 檢查所需工具是否已安裝：`docker`、`kind`、`kubectl`、`yq`、`git`
- 確保環境具備建置 GitOps 環境的基本條件

**預期輸出：**
```
🔍 Checking prerequisites...
✅ All prerequisites are installed!
```

### 1.2 理解專案結構

```bash
find . -type f -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "Makefile" -o -name "Dockerfile" | head -20
```

**作用：**
- 列出專案中的主要配置檔案
- 幫助理解 GitOps 專案的檔案架構

**重要檔案說明：**
- `clusters/kind/`: Kind 叢集配置
- `gitops/argocd/`: ArgoCD 應用定義
- `k8s/podinfo/base/`: Kustomize 基礎資源
- `k8s/podinfo/overlays/`: 環境特定覆寫
- `monitoring/`: Prometheus 監控配置

### 1.3 理解 Kustomize Overlay 概念

```bash
# 查看本地環境 overlay
cat k8s/podinfo/overlays/dev-local/kustomization.yaml

# 查看 GHCR 環境 overlay  
cat k8s/podinfo/overlays/dev-ghcr/kustomization.yaml
```

**作用：**
- 理解如何使用 overlay 管理不同環境的差異
- 學習 Kustomize 的映像覆寫機制

**關鍵差異：**
- `dev-local`: 使用 `localhost:5001` registry，UI 顏色綠色
- `dev-ghcr`: 使用 `ghcr.io` registry，UI 顏色藍色

---

## 2. Kind 叢集建立階段

### 2.1 建立 Kind 叢集與本地 Registry

```bash
make setup-cluster
```

**作用：**
- 執行 `clusters/kind/scripts/kind-with-registry.sh` 腳本
- 建立 3 節點 Kind 叢集（1 control-plane + 2 workers）
- 啟動本地 Docker registry 在 `localhost:5001`
- 配置 containerd 使用本地 registry 作為 mirror

**預期輸出關鍵點：**
```
📦 Creating local Docker registry...
🚀 Creating kind cluster...
🔌 Connecting registry to cluster network...
✅ Kind cluster 'gitops-demo' created with local registry at localhost:5001
```

### 2.2 驗證叢集狀態

```bash
kubectl get nodes
```

**作用：**
- 檢查所有節點是否處於 Ready 狀態
- 確認 Kubernetes 版本

**預期輸出：**
```
NAME                        STATUS   ROLES           AGE   VERSION
gitops-demo-control-plane   Ready    control-plane   1m    v1.33.1
gitops-demo-worker          Ready    <none>          1m    v1.33.1
gitops-demo-worker2         Ready    <none>          1m    v1.33.1
```

### 2.3 檢查 Docker 容器狀態

```bash
docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
```

**作用：**
- 確認 Kind 叢集容器正常運行
- 驗證端口映射設定（ArgoCD: 8080, Grafana: 3000, Prometheus: 9090）
- 確認本地 registry 容器在 `localhost:5001`

**重要端口映射：**
- `0.0.0.0:8080->30080/tcp`: ArgoCD UI
- `0.0.0.0:3000->30300/tcp`: Grafana
- `0.0.0.0:9090->30090/tcp`: Prometheus
- `127.0.0.1:5001->5000/tcp`: 本地 Registry

### 2.4 測試 Registry 連線

```bash
make registry-test
```

**作用：**
- 拉取 busybox 映像
- 標記並推送到本地 registry
- 驗證本地 registry 功能正常

**預期輸出：**
```
🧪 Testing local registry...
✅ Registry test passed!
```

---

## 3. ArgoCD 安裝與配置階段

### 3.1 安裝 ArgoCD

```bash
make install-argocd
```

**作用：**
- 建立 `argocd` 命名空間
- 安裝 ArgoCD 所有組件（server, controller, repo-server, redis, dex）
- 等待 ArgoCD server 就緒
- 顯示 admin 密碼

**安裝的組件：**
- `argocd-server`: Web UI 和 API 服務
- `argocd-application-controller`: 應用同步控制器
- `argocd-repo-server`: Git repository 連接服務
- `argocd-redis`: 快取服務
- `argocd-dex-server`: 身份認證服務

**重要資訊記錄：**
```
🔐 ArgoCD admin password: p9N0uL41MPdJepjc
```
> 請記下這個密碼，稍後需要用來登入 ArgoCD UI

### 3.2 驗證 ArgoCD 安裝

```bash
kubectl get pods -n argocd
```

**作用：**
- 確認所有 ArgoCD 組件都在運行
- 檢查 Pod 狀態是否為 Running

**預期狀態：**
- 所有 Pod 的 READY 欄位應為 1/1
- STATUS 應為 Running

---

## 4. 本地開發工作流程階段

### 4.1 修復 Dockerfile

由於原始多階段 Dockerfile 有路徑問題，我們簡化為：

```dockerfile
# Simple Dockerfile for podinfo demo application
FROM stefanprodan/podinfo:6.6.0

# Application already configured in base image
# Ports: 9898 (http), 9797 (metrics), 9999 (grpc)
```

**作用：**
- 直接使用 podinfo 官方映像
- 避免複雜的多階段建置問題
- 保持映像功能完整

### 4.2 建置本地映像

```bash
make dev-local-build
```

**作用：**
- 使用 `git rev-parse --short HEAD` 產生標籤
- 建置映像標記為 `localhost:5001/podinfo:dev-{commit-sha}`
- 驗證建置成功

**內部執行：**
```bash
SHA=$(git rev-parse --short HEAD)
docker build -t localhost:5001/podinfo:dev-$SHA .
```

### 4.3 推送映像到本地 Registry

```bash
make dev-local-push
```

**作用：**
- 將建置好的映像推送到本地 registry
- 驗證推送成功

**預期輸出：**
```
📤 Pushing to local registry...
✅ Image pushed!
```

### 4.4 更新 Kustomize 標籤

```bash
make dev-local-update
```

**作用：**
- 使用 `yq` 工具更新 `k8s/podinfo/overlays/dev-local/kustomization.yaml`
- 將 `newTag` 從 `dev-REPLACE_ME` 更新為實際的 commit SHA
- 這是 GitOps 的關鍵步驟：更新 Git 中的期望狀態

**實際執行：**
```bash
yq -i '.images[0].newTag = "dev-661c876"' k8s/podinfo/overlays/dev-local/kustomization.yaml
```

### 4.5 提交變更到 Git

```bash
git add -A && git commit -m "Update repo URLs and fix Dockerfile"
git push origin main
```

**作用：**
- 將所有變更提交到 Git repository
- 觸發 ArgoCD 監控 Git 變更並同步
- 完成 GitOps 工作流程的「Git 為唯一真相來源」原則

**GitOps 關鍵概念：**
- Git commit 觸發 ArgoCD 同步
- 部署狀態由 Git 決定，不是手動 kubectl apply

---

## 5. 應用部署階段

### 5.1 部署應用到 ArgoCD

```bash
make deploy-apps
```

**作用：**
- 應用所有 ArgoCD Application 定義
- 建立 `podinfo-local` 和 `podinfo-ghcr` 應用
- 建立 ApplicationSet（批量管理）

**內部執行：**
```bash
kubectl apply -f gitops/argocd/apps/
```

### 5.2 檢查應用狀態

```bash
kubectl get applications -n argocd
```

**作用：**
- 檢查 ArgoCD 應用的同步狀態
- 監控健康狀態

**狀態說明：**
- `SYNC STATUS`: Synced/OutOfSync/Unknown
- `HEALTH STATUS`: Healthy/Progressing/Degraded/Missing

### 5.3 處理 ServiceMonitor 依賴問題

由於 Prometheus 尚未安裝，ServiceMonitor CRD 不存在，我們暫時停用：

```bash
# 修改 k8s/podinfo/base/kustomization.yaml
# 註解掉 servicemonitor.yaml
git add -A && git commit -m "Disable ServiceMonitor until Prometheus is installed"
git push
```

**作用：**
- 解決 CRD 依賴問題
- 讓應用能夠成功部署
- 稍後在 Prometheus 安裝後重新啟用

### 5.4 建立命名空間並驗證部署

```bash
kubectl apply -f k8s/podinfo/overlays/dev-local/namespace.yaml
kubectl apply -f k8s/podinfo/overlays/dev-ghcr/namespace.yaml
```

**作用：**
- 手動建立命名空間確保應用能部署
- ArgoCD 有時需要命名空間預先存在

### 5.5 驗證 Pod 狀態

```bash
kubectl get pods -n demo-local
kubectl get pods -n demo-ghcr
```

**作用：**
- 檢查應用 Pod 是否正常運行
- 確認映像拉取狀態

**預期結果：**
- `demo-local`: Pod 正常運行（使用本地 registry 映像）
- `demo-ghcr`: Pod ImagePullBackOff（因為 GHCR 映像不存在，這是正常的）

### 5.6 驗證映像使用正確

```bash
kubectl describe pod -n demo-local local-podinfo-xxx | grep -A5 "Image:"
```

**作用：**
- 確認 Pod 使用的是我們推送到本地 registry 的映像
- 驗證 Kustomize 映像覆寫功能

**預期輸出：**
```
Image: localhost:5001/podinfo:dev-661c876
```

### 5.7 測試應用服務

```bash
kubectl port-forward -n demo-local svc/local-podinfo 9898:9898 &
curl -s http://localhost:9898 | jq -r '.message, .color'
```

**作用：**
- 測試應用是否正常回應
- 驗證 UI 顏色覆寫是否生效

**預期輸出：**
```
greetings from podinfo v6.6.0
#green
```

**重要驗證：**
- UI 顏色為 `#green` 證明 Kustomize overlay patch 正確生效

---

## 6. 監控系統部署階段

### 6.1 部署 kube-prometheus-stack

```bash
make deploy-monitoring
```

**作用：**
- 部署 Prometheus + Grafana + AlertManager 完整監控堆疊
- 使用 ArgoCD 管理監控系統部署
- 安裝必要的 CRDs（包含 ServiceMonitor）

**內部執行：**
```bash
kubectl apply -f monitoring/kube-prometheus-stack/application.yaml
```

### 6.2 檢查監控應用狀態

```bash
kubectl get application kube-prometheus-stack -n argocd
```

**作用：**
- 監控 kube-prometheus-stack 的部署進度
- 確認 Helm chart 正確同步

### 6.3 驗證監控組件啟動

```bash
kubectl get pods -n monitoring
```

**作用：**
- 檢查所有監控組件是否正常啟動
- 確認 Prometheus、Grafana、AlertManager 運行狀態

**重要組件：**
- `prometheus-xxx`: Prometheus 服務器
- `grafana-xxx`: Grafana 儀表板
- `alertmanager-xxx`: 告警管理器
- `node-exporter-xxx`: 節點指標收集器

### 6.4 重新啟用 ServiceMonitor

```bash
# 修改 k8s/podinfo/base/kustomization.yaml
# 取消註解 servicemonitor.yaml
git add -A && git commit -m "Re-enable ServiceMonitor after Prometheus installation"
git push
```

**作用：**
- 現在 Prometheus 已安裝，可以重新啟用 ServiceMonitor
- 讓 Prometheus 能夠自動發現並抓取 podinfo 指標

### 6.5 觸發應用同步

```bash
kubectl patch application podinfo-local -n argocd --type=json -p='[{"op": "add", "path": "/operation", "value": {"sync": {"prune": true}}}]'
```

**作用：**
- 手動觸發 ArgoCD 同步最新的 Git 變更
- 確保 ServiceMonitor 被正確部署

### 6.6 驗證 ServiceMonitor 建立

```bash
kubectl get servicemonitor -n demo-local
```

**作用：**
- 確認 ServiceMonitor 資源已建立
- 驗證 Prometheus 能夠發現目標

**預期輸出：**
```
NAME            AGE
local-podinfo   15s
```

---

## 7. 最終驗證階段

### 7.1 檢查所有應用狀態

```bash
kubectl get applications -n argocd
```

**作用：**
- 總體檢視所有 ArgoCD 應用的狀態
- 確認 GitOps 工作流程正常運作

**理想狀態：**
- `podinfo-local`: Synced & Healthy
- `kube-prometheus-stack`: Synced & Healthy
- 其他應用根據實際情況

### 7.2 驗證監控指標抓取

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
curl -s 'http://localhost:9090/api/v1/query?query=up{job="local-podinfo"}' | jq
```

**作用：**
- 測試 Prometheus 是否正確抓取 podinfo 的指標
- 驗證 ServiceMonitor 配置正確

### 7.3 存取所有服務

在新的終端視窗執行：

```bash
make port-forward-all
```

**作用：**
- 同時啟動所有服務的 port-forward
- 提供統一的服務存取點

**服務存取點：**
- ArgoCD: http://localhost:8080 (admin/p9N0uL41MPdJepjc)
- Grafana: http://localhost:3000 (admin/admin123!@#)  
- Prometheus: http://localhost:9090

---

## 🎯 GitOps 工作流程驗證

### 完整本地開發流程

```bash
# 1. 修改程式碼或配置
# 2. 執行完整發布流程
make dev-local-release

# 這個指令會自動執行：
# - docker build -t localhost:5001/podinfo:dev-{SHA}
# - docker push localhost:5001/podinfo:dev-{SHA}  
# - yq -i '.images[0].newTag = "dev-{SHA}"' k8s/podinfo/overlays/dev-local/kustomization.yaml
# - git commit -am "chore(local): bump image tag to dev-{SHA}"
# - git push
```

**GitOps 自動化流程：**
1. Git push → ArgoCD 偵測變更
2. ArgoCD 拉取新的 Kustomize 配置
3. ArgoCD 應用新配置到 Kubernetes 叢集
4. Kubernetes 拉取新映像並重新部署

### GitHub Actions CI/CD 流程

```bash
# 推送到 main 分支觸發 CI/CD
git push origin main
```

**自動化流程：**
1. GitHub Actions 觸發建置
2. 建置映像並推送到 GHCR
3. 自動更新 `k8s/podinfo/overlays/dev-ghcr/kustomization.yaml`
4. 自動提交回 Git repository
5. ArgoCD 偵測變更並同步 GHCR 版本應用

---

## 🔧 故障排除指南

### 常見問題與解決方案

#### 1. ArgoCD 應用 OutOfSync

```bash
# 手動觸發同步
kubectl patch application podinfo-local -n argocd --type=json -p='[{"op": "add", "path": "/operation", "value": {"sync": {"prune": true}}}]'
```

#### 2. ServiceMonitor 找不到

```bash
# 確認 Prometheus Operator CRDs 已安裝
kubectl get crd | grep monitoring

# 如果沒有，先安裝監控系統
make deploy-monitoring
```

#### 3. 映像拉取失敗

```bash
# 檢查本地 registry 狀態
docker ps | grep kind-registry

# 測試 registry 連線
make registry-test
```

#### 4. Pod 啟動失敗

```bash
# 查看 Pod 詳細狀態
kubectl describe pod -n demo-local podname

# 查看 Pod 日誌
kubectl logs -n demo-local podname
```

---

## 📚 學習重點總結

### 核心概念

1. **GitOps 原則**
   - Git 作為唯一真相來源
   - 聲明式配置管理
   - 自動化同步與回滾

2. **Kustomize 架構**
   - Base + Overlays 模式
   - 環境特定配置覆寫
   - 映像標籤動態更新

3. **雙 Registry 策略**
   - 本地開發快速迭代
   - 雲端 CI/CD 正式發布
   - 不可變標籤追蹤

4. **監控整合**
   - ServiceMonitor 自動發現
   - Prometheus 指標抓取
   - Grafana 視覺化展示

### 最佳實務

- 使用 commit SHA 作為映像標籤
- 避免使用 `:latest` 標籤  
- Git 變更觸發部署，非手動 kubectl
- 環境隔離與配置管理
- 完整的可觀測性建置

這個指南展示了現代 Kubernetes 應用開發的完整工作流程，從本地開發到生產部署的最佳實務。
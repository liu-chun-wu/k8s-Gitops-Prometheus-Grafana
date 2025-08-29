# K8s GitOps 環境清理指南

這份指南提供了多種方式來清理和關閉 GitOps 環境，適用於不同的使用場景。

## 📋 清理選項總覽

| 清理層次 | 保留內容 | 清理內容 | 適用場景 |
|---------|---------|---------|---------|
| **輕量清理** | 叢集、應用、容器 | Port Forward 連接 | 暫時停止存取，稍後繼續使用 |
| **中等清理** | Kind 叢集、ArgoCD | 應用程式、監控系統 | 重新部署應用，保留基礎設施 |
| **完整清理** | 專案檔案 | 叢集、容器、映像 | 完全重置，釋放所有資源 |

---

## 🔄 輕量清理：停止服務存取

### 停止 Port Forward 連接

當您執行了 `make port-forward-all` 後，需要停止這些服務存取：

```bash
# 方法 1：終止所有 kubectl port-forward 進程
pkill -f "kubectl port-forward"
```

```bash
# 方法 2：手動查找並終止特定進程
ps aux | grep "port-forward"
kill <process-id>
```

```bash
# 方法 3：終止特定服務的 port-forward
# 如果您知道特定的 PID
ps aux | grep "kubectl port-forward" | grep -v grep
kill -9 <specific-pid>
```

**預期結果：**
- http://localhost:8080 (ArgoCD) 無法存取
- http://localhost:3000 (Grafana) 無法存取  
- http://localhost:9090 (Prometheus) 無法存取
- 叢集和應用程式仍然正常運行

**何時使用：**
- 暫時不需要存取 Web UI
- 釋放本地端口供其他應用使用
- 稍後可重新執行 `make port-forward-all` 恢復存取

---

## 🧹 中等清理：保留叢集，清理應用

### 使用 Makefile 清理應用

```bash
make clean-apps
```

**作用：**
- 刪除所有 ArgoCD 應用程式
- 移除應用程式命名空間
- 保留 Kind 叢集和 ArgoCD 系統

### 手動清理應用（詳細步驟）

#### 1. 刪除 ArgoCD 應用程式

```bash
# 檢查現有應用
kubectl get applications -n argocd

# 刪除所有應用
kubectl delete applications --all -n argocd

# 刪除 ApplicationSets
kubectl delete applicationsets --all -n argocd
```

#### 2. 清理應用程式命名空間

```bash
# 刪除 podinfo 應用命名空間
kubectl delete namespace demo-local
kubectl delete namespace demo-ghcr

# 刪除監控系統命名空間
kubectl delete namespace monitoring
```

#### 3. 驗證清理結果

```bash
# 確認應用已刪除
kubectl get applications -n argocd

# 確認命名空間已刪除
kubectl get namespaces | grep -E "(demo-|monitoring)"

# ArgoCD 和 Kind 叢集應該仍在運行
kubectl get pods -n argocd
kubectl get nodes
```

**預期輸出：**
```bash
# 應用清理後
$ kubectl get applications -n argocd
No resources found in argocd namespace.

# 叢集仍運行
$ kubectl get nodes
NAME                        STATUS   ROLES           AGE   VERSION
gitops-demo-control-plane   Ready    control-plane   1h    v1.33.1
gitops-demo-worker          Ready    <none>          1h    v1.33.1
gitops-demo-worker2         Ready    <none>          1h    v1.33.1
```

**何時使用：**
- 重新部署應用程式測試
- 保留叢集基礎設施
- 避免重新建立叢集的時間成本

---

## 🗑️ 完整清理：刪除所有資源

### 方法 1：使用 Makefile 一鍵清理

```bash
make clean
```

**內部執行順序：**
1. 執行 `make clean-apps`（清理應用）
2. 執行 `make delete-cluster`（刪除叢集）
3. 清理 Docker 容器和網路

### 方法 2：手動逐步完整清理

#### Step 1：刪除 Kind 叢集

```bash
# 使用 Makefile
make delete-cluster
```

```bash
# 或手動執行
kind delete cluster --name gitops-demo
```

**預期輸出：**
```
🗑️ Deleting kind cluster...
Deleting cluster "gitops-demo" ...
```

#### Step 2：清理 Docker 容器

```bash
# 停止並移除本地 registry 容器
docker rm -f kind-registry
```

```bash
# 檢查是否還有相關容器
docker ps -a | grep -E "(kind|registry)"
```

#### Step 3：清理 Docker 映像（可選）

```bash
# 查看相關映像
docker images | grep -E "(localhost:5001|kind|podinfo)"

# 移除本地建立的映像
docker images | grep "localhost:5001/podinfo" | awk '{print $3}' | xargs docker rmi

# 清理未使用的映像（謹慎使用）
docker image prune -f
```

#### Step 4：清理 Docker 網路（自動清理）

```bash
# 檢查 kind 網路（通常會自動清理）
docker network ls | grep kind

# 如果需要手動清理
docker network rm kind 2>/dev/null || true
```

#### Step 5：清理 kubectl Context

```bash
# 查看當前 contexts
kubectl config get-contexts

# 移除 kind 相關的 context
kubectl config delete-context kind-gitops-demo 2>/dev/null || true
kubectl config delete-cluster kind-gitops-demo 2>/dev/null || true
kubectl config unset users.kind-gitops-demo 2>/dev/null || true
```

---

## 🔍 清理結果驗證

### 完整驗證檢查清單

```bash
# 1. 確認 Kind 叢集已刪除
kind get clusters
# 預期輸出：No kind clusters found.

# 2. 確認 Docker 容器已清理
docker ps -a | grep -E "(kind|registry)"
# 預期輸出：無相關容器

# 3. 確認 kubectl context 已清理
kubectl config get-contexts | grep kind
# 預期輸出：無 kind 相關 context

# 4. 確認端口已釋放
netstat -tlnp | grep -E "(8080|3000|9090)"
# 預期輸出：無相關端口佔用

# 5. 檢查 Docker 網路
docker network ls | grep kind
# 預期輸出：無 kind 網路
```

### 資源使用檢查

```bash
# 檢查 Docker 資源使用
docker system df

# 清理未使用的資源（可選）
docker system prune -f
```

---

## 🚀 重建環境

### 快速重建完整環境

```bash
# 一鍵重建（約 5 分鐘）
make quickstart
```

**重建流程：**
1. 檢查先決條件
2. 建立 Kind 叢集與本地 registry
3. 安裝 ArgoCD
4. 部署應用程式
5. 部署監控系統

### 存取重建後的服務

```bash
# 啟動所有服務存取
make port-forward-all
```

**服務存取點：**
- ArgoCD: http://localhost:8080
- Grafana: http://localhost:3000  
- Prometheus: http://localhost:9090

### 分階段重建

```bash
# 僅建立叢集
make setup-cluster

# 僅安裝 ArgoCD
make install-argocd

# 僅部署應用
make deploy-apps

# 僅部署監控
make deploy-monitoring
```

---

## 🔧 故障排除

### 清理過程中的常見問題

#### 1. 無法刪除 Kind 叢集

```bash
# 強制刪除
docker rm -f $(docker ps -aq --filter "label=io.x-k8s.kind.cluster=gitops-demo")

# 清理 kind 相關容器
docker ps -a | grep kind | awk '{print $1}' | xargs docker rm -f
```

#### 2. Registry 容器無法移除

```bash
# 強制停止並移除
docker kill kind-registry 2>/dev/null || true
docker rm -f kind-registry 2>/dev/null || true
```

#### 3. 端口仍被佔用

```bash
# 查找佔用端口的進程
lsof -ti:8080 -ti:3000 -ti:9090 | xargs kill -9 2>/dev/null || true

# 或使用 netstat 查找
netstat -tlnp | grep -E "(8080|3000|9090)"
```

#### 4. kubectl context 混亂

```bash
# 重置到預設 context
kubectl config use-context docker-desktop

# 或查看所有可用 contexts
kubectl config get-contexts
```

#### 5. Docker 資源不足

```bash
# 清理所有未使用的 Docker 資源
docker system prune -a -f --volumes

# 重啟 Docker Desktop（macOS）
osascript -e 'quit app "Docker Desktop"'
open -a "Docker Desktop"
```

---

## 📊 清理策略建議

### 不同場景的建議清理方式

#### 日常開發結束
```bash
# 僅停止 port-forward，保留環境
pkill -f "kubectl port-forward"
```

#### 測試新功能前
```bash
# 清理應用但保留叢集
make clean-apps
```

#### 釋放系統資源
```bash
# 完整清理
make clean
```

#### 長期不使用
```bash
# 完整清理 + Docker 資源清理
make clean
docker system prune -a -f
```

#### 環境出現問題
```bash
# 完全重置
make clean
make quickstart
```

---

## ⚡ 快速參考

### 常用清理指令

| 目的 | 指令 | 時間 |
|------|------|------|
| 停止服務存取 | `pkill -f "kubectl port-forward"` | < 1 分鐘 |
| 清理應用 | `make clean-apps` | 1-2 分鐘 |
| 完整清理 | `make clean` | 2-3 分鐘 |
| 重建環境 | `make quickstart` | 4-5 分鐘 |

### 檢查指令

| 檢查項目 | 指令 |
|---------|------|
| Kind 叢集 | `kind get clusters` |
| Docker 容器 | `docker ps -a \| grep kind` |
| kubectl Context | `kubectl config get-contexts` |
| 端口佔用 | `netstat -tlnp \| grep -E "(8080\|3000\|9090)"` |

---

## 💡 最佳實務

1. **循序漸進清理**：先嘗試輕量清理，再考慮完整清理
2. **保留學習資料**：專案檔案包含完整配置，建議保留
3. **定期清理 Docker**：避免映像累積佔用過多磁碟空間
4. **備份重要配置**：如有客製化配置，記得備份
5. **測試環境隔離**：使用不同的叢集名稱避免衝突

記住：Kind 叢集是完全本地的，清理不會影響其他系統或雲端資源，可以放心操作！
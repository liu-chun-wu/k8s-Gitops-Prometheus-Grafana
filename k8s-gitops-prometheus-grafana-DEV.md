
# k8s‑gitops‑prometheus‑grafana — Development Guide (Local Registry + GHCR)

> 本文件是專案的「最新」開發流程與目錄結構整合版，支援 **本機 Registry（kind local registry）** 與 **雲端 GHCR** 雙路徑；遵循 GitOps 原則，以 **Argo CD** 管理部署，並以 **kube‑prometheus‑stack** 建立觀測。

---

## 你將會得到什麼

- 一個以 **kind** 起的本機 K8s 叢集，已對接 **本機 registry**，可離線快速迭代。
- 一套 **Argo CD GitOps** 架構（可選：App‑of‑Apps / ApplicationSet），以 Git 為唯一真相，部署 **podinfo** 範例服務。
- 一套 **kube‑prometheus‑stack**（Prometheus + Alertmanager + Grafana + Operator）觀測環境，透過 **ServiceMonitor** 抓取 `/metrics`。

---

## 先備條件（Prerequisites）
- Docker（或相容的容器引擎）與 **kind**、`kubectl`、`helm`、`yq`、`git`。
- 一個 GitHub Repository 與 **GitHub Actions** 權限（若你要走 GHCR 流程）。
- （選配）GitHub Container Registry（**GHCR**）推送／拉取權限；Actions 以 `GITHUB_TOKEN` 推送需開 `packages:write`。

---

## 目錄結構（建議參考）

```
.
├─ clusters/
│  └─ kind/
│     ├─ kind-cluster.yaml            # kind 叢集 + containerd registry mirror 設定
│     └─ scripts/
│        └─ kind-with-registry.sh     # 一鍵建立叢集與本機 registry（localhost:5001）
├─ gitops/
│  └─ argocd/
│     ├─ namespace.yaml               # argocd 命名空間
│     ├─ apps/
│     │  ├─ podinfo-local.yaml        # 走本機 registry 的 Application
│     │  ├─ podinfo-ghcr.yaml         # 走 GHCR 的 Application
│     │  └─ (可選) podinfo-appset.yaml# ApplicationSet：用一個清單生兩個 App
│     └─ (可選) app-of-apps.yaml      # 母 Application：集中管理子 App
├─ k8s/
│  └─ podinfo/
│     ├─ base/                        # 共同資源（Deployment/Service 等）
│     └─ overlays/
│        ├─ dev-local/                # 指向 localhost:5001 的覆寫（本機 registry）
│        └─ dev-ghcr/                 # 指向 ghcr.io 的覆寫（GHCR）
├─ monitoring/
│  └─ kube-prometheus-stack/
│     └─ values.yaml                  # Grafana/Prometheus 等 chart 設定（請覆寫預設密碼）
├─ .github/
│  └─ workflows/
│     └─ release-ghcr.yml             # GHCR 流程：build & push + 回寫 kustomize tag
├─ Makefile                           # 本機常用指令（build/push/bump/port-forward）
└─ docs/
   └─ DEVELOPMENT.md                  # 本文件（或你的長版開發說明）
```

> 說明：`overlays/dev-local` 與 `overlays/dev-ghcr` 唯一差異就是 **image registry 與 tag**；使用 Kustomize 的 `images: {name,newName,newTag}` 覆寫，避免多份 YAML 重複。

---

## 雙路徑開發模型（Local 與 GHCR 並存）

| 面向 | dev‑local（本機 registry） | dev‑ghcr（雲端 GHCR） |
|---|---|---|
| Image 來源 | `localhost:5001/<name>:<tag>` | `ghcr.io/<org>/<name>:<sha>` |
| 推送方式 | `docker build` → `docker push localhost:5001/...` | GitHub Actions `docker/build-push-action` 推 GHCR（`GITHUB_TOKEN`） |
| 版本記錄 | 本機以 `git rev-parse --short HEAD` 產 tag，**回寫 Git** 到 `dev-local` overlay | CI 用 `${{ github.sha }}` 產 tag，**回寫 Git** 到 `dev-ghcr` overlay |
| Argo 觸發 | Argo 監看 Git，看到 overlay tag 變更就同步 | 同左（Git 為唯一真相）|
| 取像授權 | localhost 無需認證 | GHCR 公開可匿名；私有需 `imagePullSecrets` |
| 典型用途 | 迭代快速、離線可跑 | 正式 CI 供應鏈、可在他處叢集重現 |

> 為什麼一定要「回寫 Git」：Argo CD 的同步觸發是看 **Git 期望態**，不是看 registry 是否有新 image。若想自動掃 registry 並寫回 Git，可用 **Argo CD Image Updater**。

---

## 步驟 A：建立 kind 叢集 + 本機 registry

1. **建立本機 registry 並讓 kind containerd 當作 mirror**：請依官方範例（或你專案的 `kind-with-registry.sh`）建立，通常 registry 會暴露在主機 `localhost:5001`，叢集內對應 `kind-registry:5000`。
2. **（可選）直接把 image 載入節點**：`kind load docker-image your/image:tag [--name <cluster>]`，無需 registry，適合超快本機實驗。
> 常見問題：若看到「HTTP response to HTTPS client」或拉不到 image，通常是 registry/鏡像設定沒對齊，可對照 kind issue 討論逐一排查。

---

## 步驟 B：安裝 Argo CD 與啟動（App‑of‑Apps / ApplicationSet）

- 安裝 Argo CD（namespace `argocd`），並以 **App‑of‑Apps** 或 **ApplicationSet** 管理 `podinfo-local` 與 `podinfo-ghcr` 兩個子應用。App‑of‑Apps 適合叢集 bootstrap；ApplicationSet 可由清單自動產生多個 Application（注意安全與權限）。

**Application（local 版）**：`gitops/argocd/apps/podinfo-local.yaml`
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo-local
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/you/k8s-gitops-prometheus-grafana.git
    path: k8s/podinfo/overlays/dev-local
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: demo-local
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

**Application（ghcr 版）**：路徑與 namespace 改為 `overlays/dev-ghcr` / `demo-ghcr`。

**（選配）ApplicationSet 一口氣生兩個 App**：
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: podinfo-matrix
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - { env: dev-local, ns: demo-local, path: k8s/podinfo/overlays/dev-local }
          - { env: dev-ghcr,  ns: demo-ghcr,  path: k8s/podinfo/overlays/dev-ghcr }
  template:
    metadata: { name: podinfo-{{env}} }
    spec:
      project: default
      source: { repoURL: https://github.com/you/k8s-gitops-prometheus-grafana.git, path: "{{path}}", targetRevision: main }
      destination: { server: https://kubernetes.default.svc, namespace: "{{ns}}" }
      syncPolicy: { automated: { prune: true, selfHeal: true } }
```

---

## 步驟 C：Kustomize overlay（兩份，僅覆寫 image 與命名）

`k8s/podinfo/overlays/dev-local/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namePrefix: local-
namespace: demo-local
resources:
  - ../../base
images:                      # 用 Kustomize 覆寫 image 端點與 tag
  - name: ghcr.io/your-org/podinfo
    newName: localhost:5001/podinfo
    newTag: dev-REPLACE_ME
```
`k8s/podinfo/overlays/dev-ghcr/kustomization.yaml`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namePrefix: ghcr-
namespace: demo-ghcr
resources:
  - ../../base
images:
  - name: ghcr.io/your-org/podinfo
    newName: ghcr.io/your-org/podinfo
    newTag: ghcr-REPLACE_ME
```
> 以上作法符合 Kustomize 官方設計：用 `images` 來改 `name/newName/newTag`，避免大量 patch 重複。

---

## 步驟 D‑1：**GHCR 路徑（雲端 CI → 推 GHCR → 回寫 Git）**

1. **GitHub Actions 建置與推送**：建議使用 `docker/login-action` + `docker/build-push-action`，並直接以 `secrets.GITHUB_TOKEN` 登入 `ghcr.io`；Workflow 需設定 `permissions: packages: write`。
2. **回寫 Git（觸發 Argo）**：CI 完成後，把 `k8s/podinfo/overlays/dev-ghcr/kustomization.yaml` 的 `images[0].newTag` 更新為 `${{ github.sha }}` 並 commit/push。Argo CD 偵測到 Git 變更會自動同步。
3. **（私有包）叢集拉取授權**：若 GHCR 套件為私有，請建立 `imagePullSecrets`（`docker login ghcr.io` 流程與權限詳見 GH 官方文件）。

**Workflow 範例 `.github/workflows/release-ghcr.yml`**
```yaml
name: release-ghcr
on:
  push:
    branches: [ "main" ]
permissions:
  contents: write
  packages: write
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          push: true
          tags: ghcr.io/your-org/podinfo:${{ github.sha }}

      - name: Bump kustomize image tag (dev-ghcr)
        run: |
          yq -i '.images[0].newTag = "${{ github.sha }}"' k8s/podinfo/overlays/dev-ghcr/kustomization.yaml
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git commit -am "chore(ghcr): bump image tag to ${{ github.sha }}"
          git push
```
> 若你想一次推多個 registry（例如同時推 GHCR 與 Docker Hub），可參考 Docker 官方的多 registry 推送範例。

---

## 步驟 D‑2：**本機 registry 路徑（Local build/push → 回寫 Git）**

1. **Build & Push 到 localhost:5001**
```bash
SHA=$(git rev-parse --short HEAD)
docker build -t localhost:5001/podinfo:dev-$SHA .
docker push localhost:5001/podinfo:dev-$SHA
```
2. **回寫 Git（更新 `dev-local` overlay）**
```bash
yq -i '.images[0].newTag = "dev-'$(git rev-parse --short HEAD)'"' k8s/podinfo/overlays/dev-local/kustomization.yaml
git commit -am "chore(local): bump image tag"
git push
```
> 如果只是純本機實驗，也可「不走 registry」而改用 `kind load docker-image your/image:tag` 直接把 image 載入節點（但仍建議以 **不可變 tag** + 回寫 Git 來保留審計與回滾能力）。

**Makefile 範例（本機一鍵發版）**
```make
SHA := $(shell git rev-parse --short HEAD)

dev-local-release:
\tdocker build -t localhost:5001/podinfo:dev-$(SHA) .
\tdocker push localhost:5001/podinfo:dev-$(SHA)
\tyq -i '.images[0].newTag = "dev-$(SHA)"' k8s/podinfo/overlays/dev-local/kustomization.yaml
\tgit commit -am "chore(local): bump image tag to dev-$(SHA)"
\tgit push
```

---

## 觀測（kube‑prometheus‑stack）

- 建議以 Argo CD 安裝 **kube‑prometheus‑stack**，並覆寫 `values.yaml` 設定 **Grafana admin 密碼**；歷史上此 chart 在不少版本的預設密碼皆為 `admin:prom-operator`，請務必明確覆寫並/或查詢 Secret 值。
- 以 **ServiceMonitor** 來抓取你的服務（例如 podinfo 的 `/metrics`），請確保 `endpoints` 指到正確的 port 名稱；Prometheus 會依 `serviceMonitorSelector`（label/namespace selector）來選取目標。

---

## 安全與最佳實踐

- **避免使用 `:latest`**：Kubernetes 官方明確建議 **不要**在生產使用 `:latest`，會讓版本追蹤與回滾困難；改用語義版號或 **commit SHA**／digest。
- **GHCR 權限**：在 Actions 內以 `GITHUB_TOKEN` 推送 GHCR，Workflow 需開 `packages:write`。若叢集需從私有 GHCR 拉取，請配置 `imagePullSecrets`。
- **Git 為唯一真相**（Single‑Source‑of‑Truth）：所有部署變更都以「**回寫 Git**」驅動 Argo。若要自動化更新 tag，可導入 **Argo CD Image Updater** 並使用 **Git write‑back（含 Kustomize write‑back‑target）**。

---

## 疑難排解（FAQ）

- **ServiceMonitor 沒資料**：確定 `ServiceMonitor` 與 `Service` 的 port/name/label 對得上；檢查 Prometheus `serviceMonitorSelector` 是否能選到該 CR。citeturn2search1  
- **Grafana 登入不了**：用 `kubectl get secret grafana -n <ns> -o jsonpath='{.data.admin-password}' | base64 -d` 讀取目前密碼；建議在 `values.yaml` 明確覆寫。
- **kind 拉不到本機 image**：檢查本機 registry 是否與 kind 的 `containerdConfigPatches` 配對正確；或退一步以 `kind load docker-image` 直接載入。

---

## 參考文件（強烈推薦逐一收藏）
- kind 本機 registry 官方指南。citeturn0search0  
- Argo CD：Cluster Bootstrapping（App‑of‑Apps）、Declarative Setup、ApplicationSet。citeturn0search1turn0search6turn0search2  
- Kustomize 官方（kubectl 內建）：`images` 覆寫。citeturn0search3  
- GitHub Actions 推送 GHCR（Publishing Docker images）。citeturn0search9  
- Docker 官方：一次推送多個 registry（可同時 GHCR + Docker Hub）。citeturn1search4  
- Prometheus Operator：ServiceMonitor API。citeturn2search1  
- Kubernetes 官方：避免 `:latest`。citeturn3search1

---

### 一句話總結
> **把 overlay 拆成 `dev-local` 與 `dev-ghcr`**；Argo CD 各自管理；GHCR 用雲端 CI 自動 build→push→回寫 Git，本機用 Makefile 腳本 build→push 到 `localhost:5001`→回寫 Git。兩邊都遵守 **Git 為唯一真相** + **不可變 tag** 的 GitOps 原則，乾淨、可審計、可回滾。


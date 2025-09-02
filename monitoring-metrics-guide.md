# 監控指標說明（kube-prometheus-stack + K8s Views 儀表板）
_更新日期：2025-09-02_

本文件說明目前叢集（kind + Argo CD + kube-prometheus-stack）所能觀測的**核心指標**、其**重要性**與**常用 PromQL 範例**，並對照你在 `application.yaml` 中安裝的 Grafana 儀表板（Kubernetes Views 與 System 系列）。

## 儀表板總覽（已安裝）
- 15757 – Kubernetes / Views / Global
- 15758 – Kubernetes / Views / Namespaces
- 15759 – Kubernetes / Views / Nodes
- 15760 – Kubernetes / Views / Pods
- 15761 – Kubernetes / System / API Server
- 15762 – Kubernetes / System / CoreDNS
- 19105 – Prometheus

## 叢集狀態（kube-state-metrics）
重點：`kube_deployment_spec_replicas`、`kube_deployment_status_replicas_available`、`kube_pod_status_ready{condition="true"}`、`kube_pod_container_status_restarts_total`

**PromQL**
```promql
sum by (namespace, deployment) (kube_deployment_status_replicas_available)
/ sum by (namespace, deployment) (kube_deployment_spec_replicas)
```
```promql
increase(kube_pod_container_status_restarts_total[10m])
```

## 節點資源（node_exporter）
重點：`node_cpu_seconds_total`、`node_memory_MemAvailable_bytes`、`node_filesystem_avail_bytes`、`node_network_*_bytes_total`

## Pod/Container（Kubelet/cAdvisor）
重點：`container_cpu_usage_seconds_total`（配 `rate()`）、`container_memory_working_set_bytes`

**PromQL**
```promql
100 *
sum by (node, pod, container) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))
/ on(node) group_left
sum by (node) (machine_cpu_cores)
```
```promql
sum by (pod, container) (container_memory_working_set_bytes{container!=""}) / 1024 / 1024
```

## 控制平面：API Server
重點：`apiserver_request_total`、`apiserver_request_duration_seconds_bucket`（用 `histogram_quantile` 算分位數）

**PromQL**
```promql
sum(rate(apiserver_request_total{code=~"2.."}[5m])) / sum(rate(apiserver_request_total[5m]))
```
```promql
histogram_quantile(0.95, sum by (le) (rate(apiserver_request_duration_seconds_bucket[5m])))
```

## 叢集 DNS：CoreDNS
觀察錯誤率與延遲（依版本/外掛）。

## Prometheus 自身
Targets 抓取狀態（`up`）、`scrape_duration_seconds`、規則評估耗時、TSDB 容量。

## （選配）Argo CD 指標
`argocd_app_info`（含 `health_status`/`sync_status`）。

## PromQL 小抄
- `rate()` / `increase()` 區間 ≥ 抓取間隔的 2×
- `histogram_quantile(0.95, sum by (le)(rate(<*_bucket>[5m])))`

## SLO 起手式（樣例）
- 可用副本比 ≥ 99%（1h/1d）
- `increase(kube_pod_container_status_restarts_total[1h]) == 0`
- API P95 < 250ms
- DNS 錯誤率 < 0.5%
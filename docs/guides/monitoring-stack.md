# Prometheus & Grafana Monitoring Stack Guide

## Overview

This guide covers the complete monitoring stack implementation using Prometheus for metrics collection and Grafana for visualization. The stack provides comprehensive observability for your Kubernetes applications and infrastructure.

## Architecture

### Components Overview

```
┌─────────────────────────────────────────────┐
│                 Applications                 │
│         (Pods exposing metrics endpoints)    │
└─────────────────┬───────────────────────────┘
                  │ /metrics
┌─────────────────▼───────────────────────────┐
│              Prometheus Server               │
│  (Scrapes, stores, and queries time-series)  │
└─────────┬──────────────────┬────────────────┘
          │                  │
┌─────────▼────────┐   ┌────▼────────────────┐
│   AlertManager   │   │      Grafana         │
│  (Routes alerts) │   │  (Visualizations)    │
└─────────┬────────┘   └─────────────────────┘
          │
┌─────────▼────────┐
│  Discord/Slack   │
│  (Notifications) │
└──────────────────┘
```

### Data Flow

1. **Metrics Generation**: Applications expose metrics via HTTP endpoints
2. **Service Discovery**: Prometheus discovers targets via ServiceMonitors
3. **Scraping**: Prometheus pulls metrics at configured intervals
4. **Storage**: Time-series data stored in Prometheus TSDB
5. **Querying**: PromQL queries for data retrieval
6. **Visualization**: Grafana dashboards display metrics
7. **Alerting**: Rules trigger alerts sent to AlertManager
8. **Notification**: AlertManager routes to notification channels

## Prometheus Deep Dive

### Core Concepts

**Time Series Database (TSDB)**
- Optimized for time-stamped data
- Efficient compression and storage
- Fast queries for recent data
- Automatic data retention

**Pull-based Model**
- Prometheus pulls metrics from targets
- Better reliability detection
- Simpler security model
- No need for service discovery in apps

**Service Discovery**
- Kubernetes SD for automatic discovery
- File SD for static targets
- DNS SD for service records
- Custom SD via API

### Metrics Types

#### Counter
Cumulative metric that only increases:
```prometheus
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200"} 1234
```

#### Gauge
Metric that can go up or down:
```prometheus
# HELP memory_usage_bytes Current memory usage
# TYPE memory_usage_bytes gauge
memory_usage_bytes 523659264
```

#### Histogram
Samples observations and counts them in buckets:
```prometheus
# HELP http_request_duration_seconds Request latency
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"} 24054
http_request_duration_seconds_bucket{le="0.5"} 33444
http_request_duration_seconds_sum 53423
http_request_duration_seconds_count 33444
```

#### Summary
Similar to histogram but calculates quantiles:
```prometheus
# HELP go_gc_duration_seconds GC duration
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0.5"} 0.0001
go_gc_duration_seconds{quantile="0.9"} 0.0002
go_gc_duration_seconds_sum 0.3
go_gc_duration_seconds_count 1000
```

### Configuration

#### Basic Configuration

```yaml
# prometheus.yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'production'
    region: 'us-east-1'

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

rule_files:
  - '/etc/prometheus/rules/*.yaml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
```

#### ServiceMonitor Configuration

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: podinfo
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
      - demo-ghcr
      - demo-local
  selector:
    matchLabels:
      app: podinfo
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
      relabelings:
        - sourceLabels: [__meta_kubernetes_pod_name]
          targetLabel: pod
        - sourceLabels: [__meta_kubernetes_namespace]
          targetLabel: namespace
```

### PromQL Queries

#### Basic Queries

```promql
# Instant vector - current value
up

# Range vector - values over time
up[5m]

# Filtering
up{job="prometheus"}

# Regular expressions
up{job=~"prometheus|grafana"}

# Negative match
up{job!="prometheus"}
```

#### Aggregation

```promql
# Sum by label
sum by (job) (up)

# Average
avg(rate(http_requests_total[5m]))

# Maximum
max(memory_usage_bytes)

# Count
count(up == 1)

# Percentiles
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

#### Common Patterns

```promql
# Rate of increase (for counters)
rate(http_requests_total[5m])

# Increase over time window
increase(http_requests_total[1h])

# Percentage
(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100

# Alert prediction
predict_linear(disk_usage_bytes[1h], 4 * 3600) > disk_total_bytes

# Top K
topk(5, rate(http_requests_total[5m]))

# Comparison
rate(http_requests_total[5m]) > 100
```

### Recording Rules

Pre-compute expensive queries:

```yaml
groups:
  - name: aggregations
    interval: 30s
    rules:
      - record: job:http_requests:rate5m
        expr: |
          sum by (job) (
            rate(http_requests_total[5m])
          )
      
      - record: instance:node_cpu:rate5m
        expr: |
          100 - (avg by (instance) (
            irate(node_cpu_seconds_total{mode="idle"}[5m])
          ) * 100)
```

## Grafana Deep Dive

### Dashboard Design

#### Best Practices

1. **Layout Structure**
   - Overview at top
   - Detailed metrics below
   - Group related panels
   - Use consistent heights

2. **Color Schemes**
   - Green: Good/Normal
   - Yellow: Warning
   - Red: Critical/Error
   - Blue: Informational

3. **Panel Types**
   - Stat: Single values
   - Graph: Time series
   - Gauge: Percentage/Progress
   - Table: Detailed data
   - Heatmap: Distribution over time

#### Example Dashboard JSON

```json
{
  "dashboard": {
    "title": "Application Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{status}}"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "title": "Error Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m]))"
          }
        ],
        "gridPos": {
          "h": 4,
          "w": 6,
          "x": 12,
          "y": 0
        }
      }
    ]
  }
}
```

### Variables and Templates

```json
{
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "query": "label_values(up, namespace)",
        "refresh": 1
      },
      {
        "name": "pod",
        "type": "query",
        "query": "label_values(up{namespace=\"$namespace\"}, pod)",
        "refresh": 2
      }
    ]
  }
}
```

### Alerting in Grafana

```yaml
# Grafana alert rule
apiVersion: v1
kind: Alert
metadata:
  name: high-error-rate
spec:
  conditions:
    - evaluator:
        params: [0.05]
        type: gt
      operator:
        type: and
      query:
        params: ["A", "5m", "now"]
      type: query
  frequency: 60s
  handler: 1
  name: High Error Rate
  noDataState: no_data
  notifications:
    - uid: discord-channel
```

## Implementation Guide

### Step 1: Deploy Prometheus Stack

```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring/kube-prometheus-stack/values.yaml
```

### Step 2: Configure Values

```yaml
# values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    
    additionalScrapeConfigs:
      - job_name: 'custom-app'
        static_configs:
          - targets: ['app.default.svc:8080']

grafana:
  adminPassword: admin123
  persistence:
    enabled: true
    size: 10Gi
  
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'default'
          folder: ''
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards

alertmanager:
  config:
    route:
      group_by: ['alertname', 'cluster']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'discord'
    receivers:
      - name: 'discord'
        webhook_configs:
          - url: 'http://alertmanager-discord:9094'
```

### Step 3: Add ServiceMonitors

```bash
# Apply ServiceMonitor
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: app-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: metrics
      interval: 30s
EOF
```

### Step 4: Import Dashboards

```bash
# Popular dashboard IDs
# 15757: Kubernetes Cluster Overview
# 15758: Kubernetes Pod Details
# 19105: Node Exporter Full
# 7249: Kubernetes Cluster Monitoring

# Import via API
curl -X POST http://admin:admin123@localhost:3000/api/dashboards/import \
  -H "Content-Type: application/json" \
  -d '{
    "dashboard": {
      "id": 15757
    },
    "overwrite": true,
    "inputs": [
      {
        "name": "DS_PROMETHEUS",
        "type": "datasource",
        "pluginId": "prometheus",
        "value": "Prometheus"
      }
    ]
  }'
```

## Monitoring Best Practices

### Metric Naming

Follow Prometheus naming conventions:

```
# Good
http_requests_total
process_cpu_seconds_total
go_memstats_alloc_bytes

# Bad
httpRequests
CPU_Usage
memory.allocated
```

### Label Usage

```prometheus
# Good - low cardinality
http_requests_total{method="GET",status="200",endpoint="/api/users"}

# Bad - high cardinality
http_requests_total{user_id="12345",session_id="abc-def-ghi",timestamp="1234567890"}
```

### Resource Optimization

```yaml
# Optimize Prometheus resources
prometheus:
  prometheusSpec:
    resources:
      requests:
        memory: 400Mi
        cpu: 100m
      limits:
        memory: 2Gi
        cpu: 1000m
    
    # Reduce storage with downsampling
    retention: 15d
    retentionSize: 40GB
    
    # Limit samples
    enforcedSampleLimit: 100000
```

### Query Optimization

```promql
# Expensive - processes all data
sum(rate(http_requests_total[5m]))

# Better - pre-filters
sum(rate(http_requests_total{job="api"}[5m]))

# Best - uses recording rule
job:http_requests:rate5m{job="api"}
```

## Troubleshooting

### Common Issues

#### High Memory Usage

```bash
# Check cardinality
curl -s http://localhost:9090/api/v1/label/__name__/values | jq '. | length'

# Find high cardinality metrics
curl -s http://localhost:9090/api/v1/query?query=prometheus_tsdb_symbol_table_size_bytes | jq

# Drop problematic metrics
metric_relabel_configs:
  - source_labels: [__name__]
    regex: expensive_metric_.*
    action: drop
```

#### Missing Metrics

```bash
# Check targets
curl http://localhost:9090/targets

# Verify ServiceMonitor
kubectl get servicemonitor -A
kubectl describe servicemonitor <name> -n <namespace>

# Check pod annotations
kubectl get pod <pod> -o yaml | grep prometheus
```

#### Slow Queries

```promql
# Profile query
curl -s "http://localhost:9090/api/v1/query?query=<query>&stats=true"

# Use recording rules for complex queries
# Optimize time ranges
# Add label filters early
```

## Advanced Topics

### Federation

```yaml
# Federated Prometheus setup
scrape_configs:
  - job_name: 'federate'
    scrape_interval: 15s
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job="prometheus"}'
        - '{__name__=~"job:.*"}'
    static_configs:
      - targets:
          - 'prometheus-1:9090'
          - 'prometheus-2:9090'
```

### Remote Storage

```yaml
# Remote write to long-term storage
remote_write:
  - url: "http://cortex:9009/api/prom/push"
    queue_config:
      max_samples_per_send: 10000
      batch_send_deadline: 5s

remote_read:
  - url: "http://cortex:9009/api/prom"
    read_recent: true
```

### Custom Exporters

```go
// Custom exporter in Go
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    customMetric = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "custom_metric_value",
            Help: "Custom metric from application",
        },
        []string{"label"},
    )
)

func init() {
    prometheus.MustRegister(customMetric)
}

func main() {
    customMetric.WithLabelValues("example").Set(42)
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":2112", nil)
}
```

## Next Steps

- Configure [alerting](./alerting-system.md) with Discord/Slack
- Set up [ArgoCD monitoring](./argocd-gitops.md#monitoring-argocd)
- Implement [custom dashboards](#dashboard-design)
- Explore [advanced PromQL](#promql-queries)
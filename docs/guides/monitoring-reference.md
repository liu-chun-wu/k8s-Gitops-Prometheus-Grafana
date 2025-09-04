# Monitoring Reference Guide

## Prometheus Queries

### Basic Health Checks

| Query | Description | Usage |
|-------|-------------|-------|
| `up` | Service availability | Check if targets are up |
| `up{job="prometheus"}` | Specific job status | Filter by job name |

### Resource Monitoring

| Query | Description | Usage |
|-------|-------------|-------|
| `rate(container_cpu_usage_seconds_total[5m])` | CPU usage rate | 5-minute average |
| `container_memory_working_set_bytes` | Memory usage | Current memory |
| `kube_pod_container_status_restarts_total` | Pod restarts | Stability indicator |
| `(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100` | Node CPU % | Overall CPU usage |

## Grafana Dashboard IDs

| Dashboard ID | Description | Type |
|--------------|-------------|------|
| 15757 | Kubernetes Cluster Overview | Essential |
| 15758 | Kubernetes Pod Details | Essential |
| 15759 | Kubernetes Namespace View | Optional |
| 19105 | Node Exporter Full | Hardware metrics |
| 7249 | Kubernetes Cluster Monitoring | Alternative |
| 6417 | Kubernetes Cluster (Prometheus) | Alternative |

## API Queries

### Check Metrics Collection

```bash
# View Prometheus targets
curl http://localhost:9090/targets

# Check active alerts
curl http://localhost:9090/api/v1/alerts

# Query specific metric
curl "http://localhost:9090/api/v1/query?query=up"
```

## Common PromQL Patterns

### Aggregations

```promql
# Sum by label
sum by (namespace) (rate(container_cpu_usage_seconds_total[5m]))

# Average across pods
avg(container_memory_working_set_bytes)

# Max value
max(kube_pod_container_status_restarts_total)
```

### Filtering

```promql
# By namespace
{namespace="monitoring"}

# By multiple labels
{namespace="monitoring",pod=~"prometheus.*"}

# Exclude pattern
{namespace!="kube-system"}
```

### Rate Calculations

```promql
# Request rate
rate(http_requests_total[5m])

# Error rate percentage
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100
```

## ServiceMonitor Examples

### Basic ServiceMonitor

```yaml
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
      path: /metrics
```

## Useful URLs

| Service | Local URL | Purpose |
|---------|-----------|---------|
| Prometheus | `http://localhost:9090` | Metrics & queries |
| Prometheus Alerts | `http://localhost:9090/alerts` | Active alerts |
| Prometheus Targets | `http://localhost:9090/targets` | Scrape status |
| Grafana | `http://localhost:3001` | Dashboards |
| AlertManager | `http://localhost:9093` | Alert routing |

## Kubectl Commands

For all monitoring-related kubectl commands including:
- Resource monitoring
- Alert system debugging  
- Pod scaling for testing

See: [Kubectl Reference - Monitoring Section](./kubectl-reference.md#monitoring-specific)

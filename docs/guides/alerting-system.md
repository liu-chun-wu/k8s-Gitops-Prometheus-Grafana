# Alerting System Setup Guide

## Overview

This guide covers the complete alerting pipeline from Prometheus alert rules through AlertManager routing to Discord/Slack notifications. Learn how to create, manage, and optimize alerts for your Kubernetes infrastructure.

## Alerting Architecture

### Components

```
┌────────────────────────────────┐
│     Prometheus Alert Rules      │
│   (Evaluates metrics, fires)    │
└────────────┬───────────────────┘
             │
┌────────────▼───────────────────┐
│        AlertManager             │
│  (Groups, routes, deduplicates) │
└────────────┬───────────────────┘
             │
┌────────────▼───────────────────┐
│    alertmanager-discord         │
│  (Formats for Discord/Slack)    │
└────────────┬───────────────────┘
             │
┌────────────▼───────────────────┐
│     Discord/Slack Channel       │
│      (Team notification)        │
└────────────────────────────────┘
```

### Alert Lifecycle

1. **Pending**: Alert condition met but waiting for duration
2. **Firing**: Alert active and sent to AlertManager
3. **Resolved**: Condition no longer met
4. **Silenced**: Temporarily muted by operator

## Discord Integration

### Prerequisites

1. **Create Discord Webhook**:
   - Open Discord Server Settings
   - Navigate to Integrations → Webhooks
   - Click "New Webhook"
   - Choose channel and copy URL

2. **Configure Environment**:
```bash
# Create .env file
cat > .env <<EOF
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_TOKEN
EOF
```

### Installation

```bash
# Install alertmanager-discord
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: discord-webhook
  namespace: monitoring
type: Opaque
stringData:
  webhook-url: "YOUR_DISCORD_WEBHOOK_URL"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager-discord
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager-discord
  template:
    metadata:
      labels:
        app: alertmanager-discord
    spec:
      containers:
      - name: alertmanager-discord
        image: benjojo/alertmanager-discord:latest
        env:
        - name: DISCORD_WEBHOOK
          valueFrom:
            secretKeyRef:
              name: discord-webhook
              key: webhook-url
        ports:
        - containerPort: 9094
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager-discord
  namespace: monitoring
spec:
  selector:
    app: alertmanager-discord
  ports:
  - port: 9094
    targetPort: 9094
EOF
```

### AlertManager Configuration

```yaml
# alertmanager-config.yaml
global:
  resolve_timeout: 5m
  
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'discord-critical'
  
  routes:
    - match:
        severity: critical
      receiver: discord-critical
      continue: true
      
    - match:
        severity: warning
      receiver: discord-warning
      repeat_interval: 24h
      
    - match:
        alertname: Watchdog
      receiver: 'null'

receivers:
  - name: 'null'
  
  - name: 'discord-critical'
    webhook_configs:
      - url: 'http://alertmanager-discord:9094'
        send_resolved: true
        http_config:
          tls_config:
            insecure_skip_verify: true
            
  - name: 'discord-warning'
    webhook_configs:
      - url: 'http://alertmanager-discord:9094'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']
```

## Alert Rules

### Basic Alert Rule Structure

```yaml
groups:
  - name: example-alerts
    interval: 30s
    rules:
      - alert: AlertName
        expr: prometheus_expression > threshold
        for: 5m
        labels:
          severity: warning
          component: app-name
        annotations:
          summary: "Brief description of the issue"
          description: "Detailed description with {{ $labels.instance }}"
          runbook_url: "https://wiki.example.com/runbooks/AlertName"
```

### Common Alert Rules

#### Infrastructure Alerts

```yaml
groups:
  - name: infrastructure
    rules:
      # Node Down
      - alert: NodeDown
        expr: up{job="node-exporter"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "Node {{ $labels.instance }} has been down for more than 2 minutes"
      
      # High CPU Usage
      - alert: HighCPUUsage
        expr: |
          100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% (current value: {{ $value }}%)"
      
      # High Memory Usage
      - alert: HighMemoryUsage
        expr: |
          (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 90% (current value: {{ $value }}%)"
      
      # Disk Space Low
      - alert: DiskSpaceLow
        expr: |
          (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk space on {{ $labels.mountpoint }} is below 10% (current: {{ $value }}%)"
```

#### Kubernetes Alerts

```yaml
groups:
  - name: kubernetes
    rules:
      # Pod CrashLooping
      - alert: PodCrashLooping
        expr: |
          rate(kube_pod_container_status_restarts_total[5m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"
          description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has restarted {{ $value }} times in the last 5 minutes"
      
      # Deployment Replicas Mismatch
      - alert: DeploymentReplicasMismatch
        expr: |
          kube_deployment_spec_replicas != kube_deployment_status_replicas_available
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Deployment {{ $labels.namespace }}/{{ $labels.deployment }} replica mismatch"
          description: "Deployment has {{ $value }} replicas available, but expects {{ $labels.spec_replicas }}"
      
      # PVC Almost Full
      - alert: PersistentVolumeAlmostFull
        expr: |
          (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PVC {{ $labels.persistentvolumeclaim }} is almost full"
          description: "PVC is {{ $value }}% full"
      
      # Too Many Pods
      - alert: TooManyPods
        expr: |
          count by (node) (kube_pod_info) > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Node {{ $labels.node }} has too many pods"
          description: "Node is running {{ $value }} pods (threshold: 100)"
```

#### Application Alerts

```yaml
groups:
  - name: application
    rules:
      # High Error Rate
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) 
          / 
          sum(rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} over the last 5 minutes"
      
      # Slow Response Time
      - alert: SlowResponseTime
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
          ) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "95th percentile response time is slow"
          description: "95th percentile response time is {{ $value }}s"
      
      # Service Down
      - alert: ServiceDown
        expr: up{job="my-service"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.instance }} is down"
          description: "Service has been down for more than 1 minute"
```

## Testing Alerts

### Manual Alert Testing

```bash
# Test alert instantly
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-alert
  namespace: monitoring
spec:
  groups:
    - name: test
      interval: 10s
      rules:
        - alert: TestAlert
          expr: vector(1)
          for: 0m
          labels:
            severity: info
          annotations:
            summary: "Test alert is firing"
            description: "This is a test alert that always fires"
EOF

# Remove test alert
kubectl delete prometheusrule test-alert -n monitoring
```

### Simulating Real Conditions

```bash
# Simulate high CPU
kubectl run cpu-stress --image=progrium/stress --rm -it -- --cpu 2 --timeout 60s

# Simulate pod crash
kubectl run crash-pod --image=busybox --restart=Never -- sh -c "exit 1"

# Scale down deployment
kubectl scale deployment podinfo --replicas=0 -n demo-ghcr

# Create disk pressure
kubectl run disk-fill --image=busybox --rm -it -- \
  dd if=/dev/zero of=/tmp/fill bs=1M count=1000
```

## Alert Management

### Silencing Alerts

```bash
# Via AlertManager API
curl -X POST http://localhost:9093/api/v1/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {
        "name": "alertname",
        "value": "NodeMemoryPressure",
        "isRegex": false
      }
    ],
    "startsAt": "2024-01-01T00:00:00Z",
    "endsAt": "2024-01-01T02:00:00Z",
    "comment": "Maintenance window",
    "createdBy": "admin"
  }'

# List silences
curl http://localhost:9093/api/v1/silences

# Delete silence
curl -X DELETE http://localhost:9093/api/v1/silence/<silence-id>
```

### Alert Routing Strategies

```yaml
# Complex routing example
route:
  group_by: ['cluster']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'default'
  
  routes:
    # Critical alerts - immediate, frequent
    - match_re:
        severity: critical
      group_wait: 10s
      repeat_interval: 1h
      receiver: discord-critical
      
    # Database alerts - to DBA team
    - match:
        component: database
      receiver: dba-team
      routes:
        - match:
            severity: critical
          receiver: dba-oncall
          
    # Development environment - less noise
    - match:
        environment: development
      repeat_interval: 24h
      receiver: discord-dev
      
    # Business hours only
    - match:
        severity: warning
      receiver: discord-warning
      active_time_intervals:
        - business-hours

time_intervals:
  - name: business-hours
    time_intervals:
      - weekdays: ['monday:friday']
        times:
          - start_time: '09:00'
            end_time: '17:00'
```

## Slack Integration

### Setup

```yaml
# Slack configuration
receivers:
  - name: slack-notifications
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
        title: 'Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        send_resolved: true
        color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
        actions:
          - type: button
            text: 'Runbook'
            url: '{{ .CommonAnnotations.runbook_url }}'
          - type: button
            text: 'Dashboard'
            url: 'http://grafana.local/d/{{ .CommonLabels.dashboard }}'
```

## Advanced Alerting

### Alert Templates

```yaml
# Custom templates
global:
  slack_api_url: 'YOUR_SLACK_URL'

templates:
  - '/etc/alertmanager/templates/*.tmpl'

receivers:
  - name: slack-custom
    slack_configs:
      - channel: '#alerts'
        title: '{{ template "slack.title" . }}'
        text: '{{ template "slack.text" . }}'
```

Template file:
```go
{{ define "slack.title" }}
[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .GroupLabels.alertname }}
{{ end }}

{{ define "slack.text" }}
{{ range .Alerts }}
*Alert:* {{ .Annotations.summary }}
*Description:* {{ .Annotations.description }}
*Severity:* {{ .Labels.severity }}
*Started:* {{ .StartsAt.Format "15:04:05 MST" }}
{{ if .Labels.namespace }}*Namespace:* {{ .Labels.namespace }}{{ end }}
{{ if .Labels.pod }}*Pod:* {{ .Labels.pod }}{{ end }}
{{ end }}
{{ end }}
```

### Multi-cluster Alerting

```yaml
# External labels for cluster identification
global:
  external_labels:
    cluster: 'production-us-east'
    region: 'us-east-1'
    environment: 'production'

# Route based on cluster
route:
  routes:
    - match:
        cluster: production-us-east
      receiver: prod-team
    - match:
        cluster: staging
      receiver: dev-team
```

### Alert Dependencies

```yaml
# Inhibition rules
inhibit_rules:
  # If cluster is down, inhibit all other alerts from that cluster
  - source_match:
      alertname: ClusterDown
    target_match_re:
      cluster: '.*'
    equal: ['cluster']
    
  # If node is down, inhibit pod alerts on that node
  - source_match:
      alertname: NodeDown
    target_match:
      alertname: PodDown
    equal: ['node']
```

## Best Practices

### Alert Design

1. **Actionable Alerts**
   - Every alert should have a clear action
   - Include runbook links
   - Avoid noise and alert fatigue

2. **Appropriate Thresholds**
   ```yaml
   # Bad - too sensitive
   expr: cpu_usage > 50
   for: 1m
   
   # Good - reasonable threshold and duration
   expr: cpu_usage > 80
   for: 10m
   ```

3. **Meaningful Labels**
   ```yaml
   labels:
     severity: critical      # critical, warning, info
     component: database     # What component
     team: platform          # Who should respond
     environment: production # Where
   ```

4. **Useful Annotations**
   ```yaml
   annotations:
     summary: "Database connection pool exhausted"
     description: |
       Connection pool for {{ $labels.database }} is at {{ $value }}% capacity.
       Current connections: {{ $labels.current }}
       Maximum connections: {{ $labels.max }}
     runbook_url: "https://wiki.internal/runbooks/db-connection-pool"
     dashboard_url: "https://grafana.internal/d/db-dashboard"
   ```

### Testing Strategy

```yaml
# Test alerts in stages
stages:
  - name: syntax
    test: promtool check rules alert-rules.yaml
    
  - name: unit
    test: promtool test rules alert-tests.yaml
    
  - name: integration
    test: Deploy to staging and trigger conditions
    
  - name: end-to-end
    test: Verify notifications received
```

### Monitoring the Monitoring

```yaml
# Alert on alerting pipeline health
- alert: AlertmanagerDown
  expr: up{job="alertmanager"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Alertmanager is down"

- alert: PrometheusRuleFailures
  expr: prometheus_rule_evaluation_failures_total > 0
  for: 5m
  annotations:
    summary: "Prometheus rule evaluation failures"

- alert: AlertmanagerNotificationsFailed
  expr: rate(alertmanager_notifications_failed_total[5m]) > 0
  annotations:
    summary: "Alertmanager notifications are failing"
```

## Troubleshooting

### Common Issues

#### Alerts Not Firing

```bash
# Check Prometheus targets
curl http://localhost:9090/targets

# Verify alert rules loaded
curl http://localhost:9090/api/v1/rules

# Check alert state
curl http://localhost:9090/api/v1/alerts

# Validate rule syntax
promtool check rules /etc/prometheus/rules/*.yaml
```

#### Notifications Not Received

```bash
# Check AlertManager config
curl http://localhost:9093/api/v1/status

# View current alerts
curl http://localhost:9093/api/v1/alerts

# Check notification history
kubectl logs -n monitoring deployment/alertmanager-main

# Test webhook manually
curl -X POST YOUR_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"content": "Test message"}'
```

#### Too Many Alerts

```bash
# Analyze alert frequency
curl -s http://localhost:9090/api/v1/query?query=ALERTS | jq '.data.result | length'

# Find noisy alerts
curl -s http://localhost:9090/api/v1/query?query=increase(ALERTS[24h]) | jq '.data.result | sort_by(.value[1] | tonumber) | reverse | .[0:10]'

# Temporary silence
amtool silence add alertname="NoisyAlert" --duration="2h" --comment="Under investigation"
```

## Next Steps

- Review [monitoring stack](./monitoring-stack.md) setup
- Configure [ArgoCD alerts](./argocd-gitops.md)
- Implement [custom exporters](./monitoring-stack.md#custom-exporters)
- Set up [multi-cluster monitoring](./architecture.md#multi-cluster)
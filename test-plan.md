# K8s GitOps Monitoring Test Plan

**Comprehensive testing guide for Prometheus, Grafana, and AlertManager**

This test plan validates your kube-prometheus-stack monitoring setup with 5 practical scenarios. All mentioned dashboards are automatically loaded via kubernetes-mixin ConfigMaps.

## 🚀 Prerequisites & Environment Setup

### Required Tools Installation
```bash
# Install load testing tools (choose one or both)
brew install hey           # HTTP load testing (lightweight)
brew install k6            # Advanced load testing (more features)

# Verify installation
hey --version 2>/dev/null && echo "✅ hey installed" || echo "❌ hey not found"
k6 version --quiet 2>/dev/null && echo "✅ k6 installed" || echo "❌ k6 not found"
```

### Fixed Issues & Improvements
- **✅ Heredoc YAML Issue Fixed**: Test files now use separate YAML files instead of inline heredocs
- **✅ Make Commands Work**: All `make test-*` commands now work properly 
- **✅ Better Error Handling**: Tests include prerequisite checks and clear error messages
- **✅ Fast Test Alerts**: Optional fast alerts that fire in 1-2 minutes instead of 15-20 minutes

### Environment Validation
```bash
# Check monitoring stack status
make status

# Verify demo application is running (GHCR workflow)
kubectl get pods -n demo-ghcr || make deploy-app-ghcr

# Run comprehensive environment check
make test-env-check

# Access monitoring services
make access  # Shows all URLs and credentials
```

### Quick Dashboard Access
| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:30301 | admin/admin123 |
| Prometheus | http://localhost:30090 | - |
| AlertManager | http://localhost:30093 | - |

---

# 🧪 5 Core Monitoring Tests

> Each test includes: **Dashboard locations**, **Expected alerts**, **Commands**, **Success criteria**, **Cleanup**

## 🚀 **Fast Test Alerts (Optional)**

Speed up your testing with fast alerts that fire in minutes instead of 15-20 minutes!

### Deploy Fast Alerts
```bash
# Deploy fast test alerts before running tests
make test-alert-fast-deploy

# Check status
make test-alert-fast-status

# Clean up when done
make test-alert-fast-cleanup
```

### Alert Timing Comparison
| Alert | Production | Standard Test | **Fast Test** |
|-------|------------|---------------|---------------|
| PodCrashLooping | 15-20 min | 15-20 min | **1-2 min** ✨ |
| PodNotReady | 15-20 min | 15-20 min | **2-3 min** ✨ |
| NodeNotReady | 15-20 min | 15-20 min | **2-3 min** ✨ |
| CPUThrottling | 5-10 min | 5-10 min | **1-2 min** ✨ |

⚠️ **Note**: Fast alerts are for testing only - do not use in production!

---

## 1. Pod CrashLoopBackOff Test 💥

### 📊 **Where to Monitor**
- **Pod Details**: Grafana → Kubernetes / Pods
- **Workload Overview**: Grafana → Kubernetes / Deployments  
- **Alerts**: http://localhost:30093 (AlertManager)

### ⚠️ **Expected Alerts**: 
- **Standard**: `KubePodCrashLooping` (15-20 min)
- **Fast Test**: `TestPodCrashLoopingFast` (1-2 min) 🚀

### 🔧 **Execute Test**
```bash
# Method 1: Using make command (recommended)
make test-crash-loop

# Method 2: Manual approach
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crash-demo
  namespace: default
  labels:
    test: crash-loop
spec:
  containers:
  - name: boom
    image: busybox
    command: ["sh", "-c", "echo 'Crashing in 3..2..1..'; sleep 2; exit 1"]
    resources:
      limits:
        memory: "64Mi"
        cpu: "50m"
EOF

# Monitor the crashing pod
kubectl get pod crash-demo -w
```

### ✅ **Success Criteria**
- Pod shows increasing restart count
- Pod status shows `CrashLoopBackOff`
- AlertManager fires `KubePodCrashLooping` alert within ~5 minutes
- Discord notification received (if configured)

### 🧹 **Cleanup**
```bash
kubectl delete pod crash-demo
# Or: make test-crash-loop-cleanup
```

---

## 2. Node NotReady Test 🖥️

### 📊 **Where to Monitor**
- **Node Overview**: Grafana → Node Exporter / Nodes
- **Cluster Health**: Grafana → Kubernetes / Cluster
- **Kubelet Status**: Grafana → Kubernetes / Kubelet

### ⚠️ **Expected Alerts**: `KubeNodeNotReady`, `KubeletDown`

### 🔧 **Execute Test**
```bash
# Method 1: Using make command (recommended)
make test-node-failure

# Method 2: Manual approach - Find and stop a worker node
# List kind cluster nodes (avoid control-plane)
docker ps --filter "name=gitops-demo-worker" --format "table {{.Names}}\t{{.ID}}"

# Stop one worker node (replace with actual container name)
WORKER_CONTAINER=$(docker ps --filter "name=gitops-demo-worker" --format "{{.Names}}" | head -n1)
echo "Stopping node: $WORKER_CONTAINER"
docker stop $WORKER_CONTAINER

# Monitor node status
kubectl get nodes -w
```

### ✅ **Success Criteria**
- Node transitions from Ready → NotReady
- Node metrics show as unavailable in Grafana
- After ~15 minutes, `KubeNodeNotReady` alert fires
- Pods get rescheduled to other nodes

### 🧹 **Cleanup**
```bash
# Restart the stopped node
docker start $WORKER_CONTAINER
# Wait for node to become Ready
kubectl get nodes -w
# Or: make test-node-failure-cleanup
```

---

## 3. Pod NotReady Test 🚫

### 📊 **Where to Monitor**
- **Pod Status**: Grafana → Kubernetes / Pods
- **Deployment Health**: Grafana → Kubernetes / Deployments
- **Service Endpoints**: Grafana → Kubernetes / Service Discovery

### ⚠️ **Expected Alert**: `KubePodNotReady`

### 🔧 **Execute Test**
```bash
# Method 1: Using make command (recommended)
make test-pod-not-ready

# Method 2: Deploy a pod with failing readiness probe
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notready-demo
  namespace: default
  labels:
    app: notready-demo
    test: readiness-failure
spec:
  replicas: 2
  selector:
    matchLabels:
      app: notready-demo
  template:
    metadata:
      labels:
        app: notready-demo
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /non-existent-endpoint
            port: 9999  # Wrong port
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
EOF

# Monitor pod status
kubectl get pods -l app=notready-demo -w
```

### ✅ **Success Criteria**
- Pods show Running but not Ready (0/1 Ready)
- Readiness probe failures visible in pod events
- After ~15 minutes, `KubePodNotReady` alert fires
- Service endpoints show 0 available endpoints

### 🧹 **Cleanup**
```bash
kubectl delete deployment notready-demo
# Or: make test-pod-not-ready-cleanup
```

---

## 4. Alert Routing Test 📢

### 📊 **Where to Monitor**
- **AlertManager UI**: http://localhost:30093
- **Grafana Alerting**: Grafana → Alerting → Alert Rules
- **Discord Channel**: Check configured webhook channel

### ⚠️ **Expected Result**: Instant test alerts with Discord notifications

### 🔧 **Execute Test**
```bash
# Method 1: Using existing instant alert system (recommended)
make test-alert-instant

# Method 2: Direct AlertManager API injection
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093 &
PID=$!
sleep 3

# Send synthetic alert
cat <<'EOF' > /tmp/synthetic-alert.json
[{
  "labels": {
    "alertname": "TestDiscordRouting",
    "severity": "warning",
    "service": "test-routing"
  },
  "annotations": {
    "summary": "🧪 Discord routing test alert",
    "description": "This alert tests Discord webhook integration"
  },
  "startsAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "endsAt": "$(date -u -d '+5 minutes' +%Y-%m-%dT%H:%M:%SZ)"
}]
EOF

curl -XPOST "http://localhost:9093/api/v2/alerts" \
  -H 'Content-Type: application/json' \
  -d @/tmp/synthetic-alert.json

kill $PID 2>/dev/null
```

### ✅ **Success Criteria**
- Alert appears immediately in AlertManager UI
- Discord notification received within 30 seconds
- Alert shows proper routing and grouping
- Alert resolves automatically after 5 minutes

### 🧹 **Cleanup**
```bash
# Alerts auto-resolve, but you can manually silence if needed
rm -f /tmp/synthetic-alert.json
# Or: make test-alert-cleanup
```

---

## 5. Resource Pressure Test 🚀

### 📊 **Where to Monitor**
- **Pod Resources**: Grafana → Kubernetes / Compute Resources / Pod
- **Node Resources**: Grafana → Node Exporter / Nodes
- **Cluster Overview**: Grafana → Kubernetes / Cluster

### ⚠️ **Expected Alerts**: `CPUThrottlingHigh`, `PodMemoryUsageHigh`

### 🔧 **Execute Test**
```bash
# Prerequisites: Ensure podinfo is running
kubectl get pods -n demo-local || make deploy-app-local

# Method 1: Using make command (recommended)
make test-load-pressure

# Method 2: Manual load testing
# Option A: Using hey (HTTP load generator)
kubectl port-forward -n demo-local svc/local-podinfo 9898:9898 &
PID=$!
sleep 2

echo "🚀 Starting 60-second load test with hey..."
hey -z 60s -c 50 -q 100 http://localhost:9898/

kill $PID

# Option B: Using k6 (more advanced)
cat <<'EOF' > /tmp/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 50,          // 50 virtual users
  duration: '60s',  // Run for 60 seconds
};

export default function() {
  let response = http.get('http://localhost:9898/');
  check(response, {
    'status is 200': (r) => r.status === 200,
  });
  sleep(0.1);
}
EOF

kubectl port-forward -n demo-local svc/local-podinfo 9898:9898 &
PID=$!
k6 run /tmp/load-test.js
kill $PID
```

### ✅ **Success Criteria**
- CPU and memory usage increase during load test
- Metrics visible in pod and node dashboards
- If CPU limits are set low, `CPUThrottlingHigh` may fire
- Resource usage returns to baseline after test

### 🧹 **Cleanup**
```bash
rm -f /tmp/load-test.js
# Kill any remaining port-forward processes
pkill -f "port-forward.*podinfo"
# Or: make test-load-pressure-cleanup
```

---

## 📋 Test Execution Summary

### Quick Test All Commands
```bash
# Run all tests in sequence
make test-all

# Or run individually:
make test-crash-loop
make test-node-failure  
make test-pod-not-ready
make test-alert-instant
make test-load-pressure

# Cleanup everything
make test-cleanup-all
```

### Important Notes
- **Alert Timing**: Most alerts have 15-minute `for` delays to prevent false positives
- **Auto-loaded Dashboards**: All mentioned dashboards are automatically available via kubernetes-mixin
- **Runbooks**: Each alert has corresponding runbooks at [runbooks.prometheus-operator.dev](https://runbooks.prometheus-operator.dev)
- **Resource Limits**: Set appropriate CPU/memory limits to trigger throttling alerts

### Troubleshooting
- If tests fail, run `make status` to check cluster health
- Dashboard not loading? Check `make access` for correct URLs  
- No alerts firing? Verify AlertManager config with `kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0`
- Discord not working? Check webhook URL in `.env` file

---

## 🔗 References
- [Kubernetes Monitoring Mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Prometheus Runbooks](https://runbooks.prometheus-operator.dev)
- [Node Exporter Dashboards](https://grafana.com/grafana/dashboards/1860)

# System Architecture Overview

## 🏗️ Project Structure

This project implements a complete GitOps workflow using Kubernetes, ArgoCD, Prometheus, and Grafana to create a modern cloud-native application deployment and monitoring system.

```
k8s-gitops-prometheus-grafana/
├── clusters/               # Kind cluster configurations
│   └── gitops-demo.yaml   # Multi-node cluster with registry
├── gitops/                # ArgoCD application definitions
│   ├── apps/              # Application manifests
│   └── bootstrap/         # ArgoCD self-management
├── k8s/                   # Kubernetes resources
│   └── podinfo/           # Demo application
│       ├── base/          # Base Kustomization
│       └── overlays/      # Environment-specific configs
├── monitoring/            # Monitoring stack
│   ├── kube-prometheus-stack/  # Prometheus + Grafana
│   └── alerts/                  # Alert rules and routing
└── ingress/               # Ingress controllers and rules
```

## 🔄 GitOps Workflow

### Core Principles

1. **Git as Single Source of Truth**: All configurations stored in Git
2. **Declarative Configuration**: Desired state defined in YAML
3. **Automated Reconciliation**: ArgoCD continuously syncs Git → Cluster
4. **Pull-based Deployment**: Cluster pulls changes, not pushed from CI

### Flow Diagram

```
Developer → Git Push → GitHub Repository
                            ↓
                        ArgoCD Poll
                            ↓
                    Kubernetes Cluster
                            ↓
                    Application Pods
                            ↓
                 Prometheus Monitoring
                            ↓
                   Grafana Dashboard
                            ↓
                 AlertManager → Discord
```

## 🎯 Components

### 1. Infrastructure Layer

**Kind (Kubernetes in Docker)**
- Local Kubernetes cluster for development
- Multi-node setup with control plane and workers
- Integrated local Docker registry (port 5001)
- Persistent volume support

### 2. GitOps Layer

**ArgoCD**
- Continuous delivery for Kubernetes
- Watches Git repository for changes
- Automatic or manual sync policies
- Multi-environment support (local/GHCR)
- Self-healing capabilities

### 3. Application Layer

**Podinfo**
- Lightweight Go microservice
- REST API with health endpoints
- Prometheus metrics exposure
- Multiple deployment environments

### 4. Monitoring Layer

**Prometheus**
- Metrics collection and storage
- Service discovery via ServiceMonitors
- Alert rule evaluation
- PromQL query engine

**Grafana**
- Visualization dashboards
- Pre-configured datasources
- Kubernetes-specific dashboards
- Custom alert panels

**AlertManager**
- Alert routing and grouping
- Notification channel management
- Silence and inhibition rules
- Discord webhook integration

## 🌐 Networking

### Service Exposure

1. **NodePort Services**
   - Direct access to services
   - Fixed port mappings
   - Development convenience

2. **Ingress Controller**
   - NGINX-based routing
   - Host-based routing (argocd.local)
   - SSL termination capability

3. **Port Forwarding**
   - kubectl port-forward
   - Direct pod access
   - Debugging tool

### Network Flow

```
External Request
    ↓
Ingress Controller (80/443)
    ↓
Service (ClusterIP)
    ↓
Pod (Container Port)
```

## 📦 Deployment Modes

### Local Registry Mode

- Build and push to localhost:5001
- Fast iteration cycles
- No external dependencies
- Ideal for development

### GHCR (GitHub Container Registry) Mode

- Production-ready images
- Version control integration
- Public/private image support
- CI/CD pipeline ready

### Dual Mode

- Both registries active
- Environment separation
- A/B testing capability
- Migration path

## 🔐 Security Considerations

### Development Environment

- Fixed passwords for convenience
- Local-only access by default
- No TLS enforcement
- Simplified RBAC

### Production Recommendations

1. **Secret Management**
   - Use Sealed Secrets or External Secrets
   - Rotate credentials regularly
   - Encrypt sensitive data

2. **Network Policies**
   - Implement zero-trust networking
   - Restrict pod-to-pod communication
   - Enable firewall rules

3. **RBAC**
   - Fine-grained permissions
   - Service account isolation
   - Audit logging

4. **Image Security**
   - Vulnerability scanning
   - Signed images
   - Private registries

## 🔄 Data Flow

### Metrics Pipeline

```
Application Metrics (Podinfo)
    ↓
Prometheus Scrape (ServiceMonitor)
    ↓
Time-series Storage (Prometheus)
    ↓
Query API (PromQL)
    ↓
Visualization (Grafana)
```

### Alert Pipeline

```
Metric Threshold Breach
    ↓
Alert Rule Evaluation (Prometheus)
    ↓
Alert Generation
    ↓
AlertManager Routing
    ↓
Discord Webhook
    ↓
Team Notification
```

## 🛠️ Customization Points

### Application Level
- Custom container images
- Environment variables
- Resource limits
- Replica counts

### Monitoring Level
- Custom dashboards
- Alert thresholds
- Scrape intervals
- Retention policies

### Infrastructure Level
- Cluster size
- Node resources
- Storage classes
- Network plugins

## 📈 Scalability

### Horizontal Scaling
- HPA (Horizontal Pod Autoscaler)
- Cluster autoscaling
- Load balancing

### Vertical Scaling
- Resource adjustments
- Node upgrades
- Storage expansion

### Multi-cluster
- ArgoCD ApplicationSets
- Federated Prometheus
- Cross-cluster networking
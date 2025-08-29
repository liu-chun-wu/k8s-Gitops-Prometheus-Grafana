# K8s GitOps + Prometheus + Grafana - Quick Start Guide

## Prerequisites

Ensure you have the following tools installed:
- Docker
- kind
- kubectl
- helm
- yq
- git

Check prerequisites:
```bash
make check-prereqs
```

## Quick Start (5 minutes)

1. **Complete setup from scratch:**
   ```bash
   make quickstart
   ```
   This will:
   - Create a kind cluster with local registry
   - Install ArgoCD
   - Install NGINX Ingress Controller
   - Deploy applications
   - Deploy monitoring stack

2. **Setup Ingress access (recommended):**
   ```bash
   # Setup ArgoCD Ingress and apply fixed password
   make setup-argocd-ingress
   kubectl apply -f gitops/argocd/argocd-secret.yaml
   kubectl rollout restart deployment argocd-server -n argocd
   
   # Add to /etc/hosts
   sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'
   ```

3. **Access services:**
   
   **Via Ingress (recommended):**
   - ArgoCD: http://argocd.local (admin/admin123)
   - Grafana: http://localhost:3001 (admin/admin123)
   - Prometheus: http://localhost:9090
   
   **Via Port-forward (alternative):**
   ```bash
   make port-forward-all
   ```
   - ArgoCD: http://localhost:8080 (admin/admin123)
   - Grafana: http://localhost:3000 (admin/admin123)
   - Prometheus: http://localhost:9090

## Local Development Workflow

1. **Make code changes** (modify Dockerfile or application)

2. **Build, push and deploy:**
   ```bash
   make dev-local-release
   ```
   This will:
   - Build new image with commit SHA tag
   - Push to local registry (localhost:5001)
   - Update kustomization.yaml
   - Commit changes to git
   - ArgoCD will automatically sync

3. **Check application status:**
   ```bash
   make status
   ```

## Manual Steps

### 1. Cluster Setup
```bash
# Create cluster
make setup-cluster

# Verify cluster
kubectl get nodes
```

### 2. ArgoCD Installation with Ingress
```bash
# Install ArgoCD
make install-argocd

# Install Ingress and configure ArgoCD access
make install-ingress
make setup-argocd-ingress

# Apply fixed password for dev environment
kubectl apply -f gitops/argocd/argocd-secret.yaml
kubectl rollout restart deployment argocd-server -n argocd

# Access via http://argocd.local (admin/admin123)
```

### 3. Deploy Applications
```bash
# Deploy podinfo applications
make deploy-apps

# Deploy monitoring stack
make deploy-monitoring
```

## Two Development Paths

### Path 1: Local Registry (Fast Iteration)
- Uses localhost:5001 registry
- Good for rapid development
- Images stored locally

```bash
make dev-local-release
```

### Path 2: GitHub Container Registry (CI/CD)
- Uses GitHub Actions
- Pushes to ghcr.io
- Automatic on git push to main

Simply push to main branch:
```bash
git push origin main
```

## Monitoring

### Prometheus
- Access: http://localhost:9090
- Scrapes metrics from podinfo `/metrics` endpoint
- 30-day retention

### Grafana
- Access: http://localhost:3000
- Login: admin/admin123!@#
- Pre-configured dashboards for Kubernetes monitoring
- Custom dashboards for podinfo metrics

## Troubleshooting

### Common Issues

1. **Registry connection issues:**
   ```bash
   make registry-test
   ```

2. **Check ArgoCD logs:**
   ```bash
   make logs-argocd
   ```

3. **Reset everything:**
   ```bash
   make clean
   make quickstart
   ```

### ArgoCD Application Sync Issues
- Check if repository URL is correct in application manifests
- Verify git repository is accessible
- Check ArgoCD has proper permissions

### Image Pull Issues
- For local registry: ensure kind-registry is running
- For GHCR: check image exists and is public/accessible

## Cleanup

```bash
# Remove applications only
make clean-apps

# Remove everything including cluster
make clean
```

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │    │   Git Repository │    │   Kind Cluster  │
│                 │    │                  │    │                 │
│ Local Changes───┼───▶│  Kustomize       │◀───┼───ArgoCD        │
│ make dev-local  │    │  Overlays        │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                        │
                              │                        ▼
                              │                ┌─────────────────┐
                              │                │   Monitoring    │
                              │                │                 │
                              ▼                │ Prometheus      │
                       ┌──────────────────┐    │ Grafana         │
                       │ Container Registry│    │ AlertManager    │
                       │                  │    └─────────────────┘
                       │ localhost:5001   │
                       │ ghcr.io          │
                       └──────────────────┘
```

## Next Steps

- Customize podinfo application
- Add more monitoring dashboards
- Configure alerting rules
- Add additional applications to GitOps
# Local Development Setup Guide

## Prerequisites

### Required Software

Before starting, ensure you have the following tools installed:

| Tool | Purpose | Installation |
|------|---------|-------------|
| Docker Desktop | Container runtime | [Download](https://www.docker.com/products/docker-desktop) |
| Kind | Local Kubernetes | `brew install kind` or [releases](https://github.com/kubernetes-sigs/kind/releases) |
| kubectl | Kubernetes CLI | `brew install kubectl` or [docs](https://kubernetes.io/docs/tasks/tools/) |
| Make | Build automation | Pre-installed on macOS/Linux |

### System Requirements

- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 20GB free space
- **OS**: macOS, Linux, or Windows with WSL2

## Understanding Local Development

### What is Local Registry?

A local Docker registry is a private container image repository running on your machine. In this setup:

1. **Registry runs at `localhost:5001`**
2. **Accessible only from your machine and Kind cluster**
3. **No authentication required**
4. **Images persist between cluster recreations**

### Why Use Local Development?

**Advantages:**
- ⚡ Fast build-push-deploy cycles (seconds vs minutes)
- 🔒 No external dependencies or internet required
- 💰 No cloud costs or quotas
- 🛠️ Full control over the environment
- 🔄 Easy experimentation and rollback

**Use Cases:**
- Feature development
- Testing configurations
- Learning Kubernetes
- Debugging issues
- Demo environments

## Step-by-Step Setup

### 1. Initial Cluster Creation

```bash
# Create cluster with local registry
make setup-local
```

This command:
1. Creates a Kind cluster named `gitops-demo`
2. Starts a local Docker registry on port 5001
3. Configures the cluster to trust the registry
4. Sets up persistent volume storage

### 2. Verify Cluster Status

```bash
# Check cluster nodes
kubectl get nodes

# Expected output:
NAME                        STATUS   ROLES           AGE   VERSION
gitops-demo-control-plane   Ready    control-plane   1m    v1.27.3
gitops-demo-worker          Ready    <none>          1m    v1.27.3
```

### 3. Install ArgoCD

```bash
# Deploy ArgoCD
make install-argocd

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 4. Configure Ingress

```bash
# Setup ingress controller
make ingress

# Add hostname to /etc/hosts
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'

# Verify ingress
curl -I http://argocd.local
```

### 5. Deploy Applications

```bash
# Deploy local applications
make deploy-local

# Check application status
kubectl get applications -n argocd
```

## Development Workflow

### The Development Cycle

```
┌─────────────┐
│ Code Change │
└──────┬──────┘
       ↓
┌─────────────┐
│ Docker Build│
└──────┬──────┘
       ↓
┌─────────────┐
│ Push to     │
│ Local Reg   │
└──────┬──────┘
       ↓
┌─────────────┐
│ Update K8s  │
│ Manifest    │
└──────┬──────┘
       ↓
┌─────────────┐
│ ArgoCD Sync │
└──────┬──────┘
       ↓
┌─────────────┐
│ Pods Update │
└─────────────┘
```

### Quick Development Commands

```bash
# One command to do everything
make dev

# This runs:
# 1. docker build
# 2. docker push
# 3. update manifests
# 4. git commit & push
# 5. ArgoCD sync
```

### Manual Development Steps

If you prefer manual control:

```bash
# 1. Build your image
docker build -t localhost:5001/podinfo:dev-$(date +%s) .

# 2. Push to local registry
docker push localhost:5001/podinfo:dev-$(date +%s)

# 3. Update Kubernetes manifest
vim k8s/podinfo/overlays/dev-local/kustomization.yaml
# Change the image tag

# 4. Commit and push
git add -A
git commit -m "Update image tag"
git push

# 5. Sync ArgoCD (automatic or manual)
argocd app sync podinfo-local
```

## Registry Management

### Testing Registry Connectivity

```bash
# Test registry is accessible
curl http://localhost:5001/v2/_catalog

# List images in registry
curl http://localhost:5001/v2/_catalog | jq

# Get tags for an image
curl http://localhost:5001/v2/podinfo/tags/list | jq
```

### Registry Troubleshooting

```bash
# Check registry container
docker ps | grep registry

# View registry logs
docker logs kind-registry

# Restart registry if needed
docker restart kind-registry

# Verify cluster can reach registry
kubectl run test --image=localhost:5001/podinfo:latest --rm -it --command -- echo "Registry works!"
```

## Working with Kustomize

### Understanding Overlays

```
k8s/podinfo/
├── base/                 # Shared configurations
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    └── dev-local/       # Local-specific configs
        ├── kustomization.yaml
        └── patch-deployment.yaml
```

### Customizing Deployments

Edit `k8s/podinfo/overlays/dev-local/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: demo-local
namePrefix: local-

resources:
  - ../../base

images:
  - name: ghcr.io/stefanprodan/podinfo
    newName: localhost:5001/podinfo
    newTag: dev-latest  # Your custom tag

replicas:
  - name: podinfo
    count: 3

patches:
  - target:
      kind: Deployment
      name: podinfo
    patch: |
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: "128Mi"
```

## Debugging Local Development

### Common Issues and Solutions

#### Registry Connection Refused

```bash
# Problem: Can't push to localhost:5001
# Solution: Ensure registry is running
docker run -d --restart=always -p 5001:5000 --name kind-registry registry:2

# Connect registry to Kind network
docker network connect kind kind-registry
```

#### ArgoCD Not Syncing

```bash
# Check application status
kubectl get app podinfo-local -n argocd -o yaml

# Force refresh
kubectl patch app podinfo-local -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Check repository access
kubectl logs -n argocd deployment/argocd-repo-server
```

#### Pod ImagePullBackOff

```bash
# Check the exact error
kubectl describe pod <pod-name> -n demo-local

# Verify image exists in registry
curl http://localhost:5001/v2/podinfo/tags/list

# Try pulling manually
docker pull localhost:5001/podinfo:dev-latest
```

## Advanced Local Development

### Using Docker Compose

For complex applications with dependencies:

```yaml
# docker-compose.local.yml
version: '3.8'
services:
  app:
    build: .
    image: localhost:5001/myapp:latest
    depends_on:
      - db
      - redis
  
  db:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: local
  
  redis:
    image: redis:alpine
```

### Hot Reloading with Skaffold

```yaml
# skaffold.yaml
apiVersion: skaffold/v2beta29
kind: Config
build:
  artifacts:
    - image: localhost:5001/podinfo
      docker:
        dockerfile: Dockerfile
  local:
    push: true
deploy:
  kubectl:
    manifests:
      - k8s/podinfo/overlays/dev-local
```

### Volume Mounts for Development

```yaml
# For live code updates without rebuilds
apiVersion: v1
kind: PersistentVolume
metadata:
  name: code-volume
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /path/to/your/code
    type: Directory
```

## Best Practices

1. **Use meaningful tags**: `dev-feature-name` instead of `latest`
2. **Clean up regularly**: `docker system prune -a`
3. **Version your configs**: Track kustomization.yaml in Git
4. **Document changes**: Clear commit messages
5. **Test before pushing**: Run locally first
6. **Monitor resources**: `kubectl top nodes` and `docker stats`
7. **Backup important work**: Registry data isn't persistent by default

## Next Steps

- Explore [monitoring setup](./monitoring-stack.md)
- Configure [alerting](./alerting-system.md)
- Learn about [GHCR deployment](./ghcr-setup.md)
- Understand [GitOps workflow](./argocd-gitops.md)
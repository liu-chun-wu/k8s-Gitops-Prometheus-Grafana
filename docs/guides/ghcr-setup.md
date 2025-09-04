# GitHub Container Registry (GHCR) Setup Guide

## Overview

GitHub Container Registry (GHCR) is GitHub's container image hosting service, providing seamless integration with GitHub repositories and Actions. This guide covers setting up GHCR for production deployments.

## Why Use GHCR?

### Advantages

- **GitHub Integration**: Direct integration with repositories and Actions
- **Free Tier**: Generous free tier for public images
- **Security**: Built-in vulnerability scanning
- **Performance**: Global CDN for fast pulls
- **Versioning**: Automatic linking to Git commits and tags

### Use Cases

- Production deployments
- Multi-environment testing
- Public image distribution
- CI/CD pipelines
- Team collaboration

## Initial Setup

### 1. GitHub Account Configuration

Ensure you have:
- Active GitHub account
- Repository for your project
- Personal Access Token (PAT) for authentication

### 2. Create Personal Access Token

```bash
# Navigate to GitHub Settings
GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)

# Generate new token with permissions:
- read:packages (for pulling images)
- write:packages (for pushing images)
- delete:packages (optional, for cleanup)

# Save the token securely!
```

### 3. Docker Login to GHCR

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Verify login
docker pull ghcr.io/stefanprodan/podinfo:latest
```

## Building and Pushing Images

### Image Naming Convention

GHCR images follow this format:
```
ghcr.io/<owner>/<repository>:<tag>
```

Example:
```
ghcr.io/johnsmith/my-app:v1.0.0
```

### Build and Push Workflow

```bash
# 1. Build your image
docker build -t ghcr.io/$GITHUB_USERNAME/podinfo:latest .

# 2. Tag with version
docker tag ghcr.io/$GITHUB_USERNAME/podinfo:latest \
           ghcr.io/$GITHUB_USERNAME/podinfo:v1.0.0

# 3. Push to GHCR
docker push ghcr.io/$GITHUB_USERNAME/podinfo:latest
docker push ghcr.io/$GITHUB_USERNAME/podinfo:v1.0.0

# 4. Verify in GitHub
# Go to your GitHub profile → Packages
```

## Public vs Private Images

### Public Images (Recommended for demos)

**Setup:**
1. Push image to GHCR
2. Navigate to GitHub → Your Profile → Packages
3. Click on the package
4. Settings → Danger Zone → Change visibility → Public

**Benefits:**
- No authentication required for pulling
- Simpler Kubernetes deployments
- Ideal for open-source projects

**Usage in Kubernetes:**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: app
        image: ghcr.io/username/app:latest
        # No imagePullSecrets needed for public images
```

### Private Images

**Setup Image Pull Secret:**

```bash
# Create namespace
kubectl create namespace demo-ghcr

# Create docker-registry secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=$GITHUB_EMAIL \
  -n demo-ghcr

# Verify secret
kubectl get secret ghcr-secret -n demo-ghcr
```

**Usage in Kubernetes:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: demo-ghcr
spec:
  template:
    spec:
      imagePullSecrets:
      - name: ghcr-secret
      containers:
      - name: app
        image: ghcr.io/username/app:latest
```

## GitHub Actions Integration

### Automated Build and Push

Create `.github/workflows/docker-publish.yml`:

```yaml
name: Build and Push to GHCR

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Log in to GHCR
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### Multi-Architecture Builds

```yaml
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
```

## Kubernetes Deployment

### Quick Deployment

```bash
# Deploy GHCR-based application
make deploy-ghcr

# Verify deployment
kubectl get pods -n demo-ghcr
```

### Manual Deployment

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ghcr-podinfo
  namespace: demo-ghcr
spec:
  replicas: 2
  selector:
    matchLabels:
      app: podinfo
  template:
    metadata:
      labels:
        app: podinfo
    spec:
      # Only needed for private images
      # imagePullSecrets:
      # - name: ghcr-secret
      containers:
      - name: podinfo
        image: ghcr.io/stefanprodan/podinfo:6.0.0
        ports:
        - containerPort: 9898
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

## ArgoCD Configuration

### Application Definition

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo-ghcr
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/username/k8s-configs
    targetRevision: main
    path: k8s/podinfo/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: demo-ghcr
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### Image Updater Configuration

For automatic image updates:

```yaml
# argocd-image-updater annotation
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: |
      podinfo=ghcr.io/username/podinfo:~1.0
    argocd-image-updater.argoproj.io/write-back-method: git
```

## Security Best Practices

### 1. Token Management

```bash
# Use environment variables
export GHCR_TOKEN=$(cat ~/.ghcr-token)

# Never commit tokens
echo ".ghcr-token" >> .gitignore
```

### 2. Vulnerability Scanning

GitHub automatically scans public images. Check results:
1. Go to package page
2. Click "Security" tab
3. Review vulnerabilities

### 3. Image Signing

```bash
# Install cosign
brew install cosign

# Generate keys
cosign generate-key-pair

# Sign image
cosign sign ghcr.io/username/app:v1.0.0

# Verify signature
cosign verify ghcr.io/username/app:v1.0.0
```

### 4. Access Control

```yaml
# Repository permissions
Settings → Manage access → Add teams/users

# Package permissions
Package settings → Manage access → Configure
```

## Troubleshooting

### Authentication Issues

```bash
# Problem: Unauthorized error
# Solution: Refresh token
docker logout ghcr.io
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

# Verify token permissions
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user/packages
```

### Pull Rate Limits

```bash
# Check rate limit status
curl -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/rate_limit

# For anonymous pulls (public images)
# Limit: 100 pulls per 6 hours per IP
```

### Image Not Found

```bash
# Verify image exists
docker pull ghcr.io/username/app:tag

# Check visibility settings
# GitHub → Packages → Package settings

# For private images, ensure secret exists
kubectl get secret ghcr-secret -n namespace
```

### Kubernetes Pull Errors

```bash
# Check pod events
kubectl describe pod <pod-name> -n demo-ghcr

# Common issues:
# - ErrImagePull: Check image name/tag
# - ImagePullBackOff: Check credentials
# - Forbidden: Check package visibility

# Debug with temporary pod
kubectl run debug --image=ghcr.io/username/app:tag --rm -it -- sh
```

## Cost Optimization

### Storage Limits

| Plan | Storage | Bandwidth |
|------|---------|-----------|
| Free | 500MB | 1GB/month |
| Pro | 2GB | 10GB/month |
| Team | 2GB | 10GB/month |
| Enterprise | 50GB | 100GB/month |

### Cleanup Strategies

```bash
# Delete old images
gh api -X DELETE /user/packages/container/app/versions/<version-id>

# Automated cleanup with GitHub Actions
- name: Delete old packages
  uses: actions/delete-package-versions@v4
  with:
    package-name: 'app'
    min-versions-to-keep: 5
```

## Migration from Docker Hub

### Step-by-Step Migration

```bash
# 1. Pull from Docker Hub
docker pull username/app:latest

# 2. Re-tag for GHCR
docker tag username/app:latest ghcr.io/username/app:latest

# 3. Push to GHCR
docker push ghcr.io/username/app:latest

# 4. Update Kubernetes manifests
# Change: username/app:latest
# To: ghcr.io/username/app:latest

# 5. Update CI/CD pipelines
```

## Best Practices

1. **Use semantic versioning**: `v1.0.0` instead of `latest`
2. **Automate with GitHub Actions**: Consistent builds
3. **Enable vulnerability scanning**: Security first
4. **Document image contents**: README in repository
5. **Use multi-stage builds**: Smaller images
6. **Implement retention policies**: Manage storage
7. **Monitor pull rates**: Avoid rate limits
8. **Use image signing**: Verify authenticity

## Next Steps

- Set up [monitoring](./monitoring-stack.md) for GHCR deployments
- Configure [alerts](./alerting-system.md) for deployment issues
- Implement [GitOps workflow](./argocd-gitops.md) with GHCR
- Explore [local development](./local-setup.md) alongside GHCR
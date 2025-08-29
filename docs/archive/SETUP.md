# Setup Instructions

## Before You Start

This guide will help you set up a complete K8s GitOps environment with monitoring.

### Update Repository URLs

**IMPORTANT**: Before running any commands, update the repository URLs in the following files with your actual GitHub repository:

1. `gitops/argocd/apps/podinfo-local.yaml` - Line 10
2. `gitops/argocd/apps/podinfo-ghcr.yaml` - Line 10  
3. `gitops/argocd/apps/podinfo-appset.yaml` - Line 19
4. `gitops/argocd/app-of-apps.yaml` - Line 10

Replace `YOUR_USERNAME` with your GitHub username:
```yaml
repoURL: https://github.com/YOUR_USERNAME/k8s-gitops-prometheus-grafana.git
```

### For GHCR Workflow

Update `.github/workflows/release-ghcr.yml` - Line 10:
```yaml
IMAGE_NAME: ${{ github.repository }}/podinfo
```

## Step-by-Step Setup

### 1. Prerequisites Check
```bash
make check-prereqs
```

### 2. Create Cluster
```bash
make setup-cluster
```

### 3. Install ArgoCD
```bash
make install-argocd
```

### 4. Deploy Applications
```bash
make deploy-apps
make deploy-monitoring
```

### 5. Access Services
```bash
make port-forward-all
```

## Verification

1. **Check cluster status:**
   ```bash
   make status
   ```

2. **Access ArgoCD:**
   - URL: http://localhost:8080
   - Username: admin
   - Password: Get with: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

3. **Access Grafana:**
   - URL: http://localhost:3000
   - Username: admin
   - Password: admin123!@#

4. **Access Prometheus:**
   - URL: http://localhost:9090

## Next Steps

- Make code changes and run `make dev-local-release`
- Push to main branch to trigger CI/CD
- Explore monitoring dashboards in Grafana
- Check application logs and metrics
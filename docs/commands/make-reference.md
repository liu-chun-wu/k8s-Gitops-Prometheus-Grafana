# Make Command Reference

## Setup & Installation

### Quick Start

| Command | Description | Prerequisites |
|---------|-------------|---------------|
| `make quickstart` | Interactive mode selection | .env file required |
| `make quickstart-local` | Local development setup | .env + Docker |
| `make quickstart-ghcr` | Production setup with GHCR | .env + GitHub access |

### DNS Configuration

| Command | Description | Usage |
|---------|-------------|-------|
| `sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'` | Add ArgoCD hostname | Required for ingress |

### Initial Setup Components

| Command | Description | When to Use |
|---------|-------------|-------------|
| `make deploy-monitoring` | Deploy Prometheus/Grafana | Manual setup only |
| `make alert-install` | Install Discord alerting | If not via quickstart |

## Development Workflow

### Local Development

| Command | Description | When to Use |
|---------|-------------|-------------|
| `make develop-local` | Build → Push → Sync ArgoCD | Active development cycle |
| `make build-local` | Build Docker image only | Testing builds |
| `make deploy-app-local` | Deploy ArgoCD app only | After cluster exists |

### GHCR Production

| Command | Description | When to Use |
|---------|-------------|-------------|
| `make release-ghcr MSG="..."` | Full release (commit→push→wait→sync) | Production release |
| `make deploy-app-ghcr` | Deploy GHCR ArgoCD app only | After cluster exists |
| `make release-status` | Check GitHub Actions status | Monitor CI/CD |

### Monitoring & Alerts

| Command | Description | When to Use |
|---------|-------------|-------------|
| `make alert-update-webhook` | Update Discord webhook | Changed webhook URL |
| `make alert-uninstall` | Remove alerting system | Cleanup |
| `make alert-status` | Check alert system | Verify setup |

## Operations & Maintenance

### Status & Health

| Command | Description | Output |
|---------|-------------|--------|
| `make status` | System overview | Pod status + metrics API |
| `make metrics-status` | Metrics-server health | Resource monitoring status |
| `make logs` | ArgoCD logs | Recent logs |
| `make access` | Show all service URLs | URLs and credentials |

### Service Control

| Command | Description | Impact |
|---------|-------------|--------|
| `make pause-services` | Stop all services | Preserves data |
| `make resume-services` | Start all services | With health checks |

## Cleanup & Recovery

### Cleanup Commands

| Command | Description | Scope |
|---------|-------------|-------|
| `make clean` | Delete entire cluster | Full cleanup |
| `docker system prune -a` | Clean Docker cache | Free space |

### Recovery Commands

| Command | Description | Usage |
|---------|-------------|-------|
| `make resume-services` | Restart paused services | After pause |
| `make clean && make quickstart` | Full rebuild | Nuclear option |

## Environment Variables

### Configuration Variables

| Variable | Default | Usage | Example |
|----------|---------|-------|---------|
| `CLUSTER_NAME` | gitops-demo | Cluster identifier | Custom cluster name |
| `REGISTRY_PORT` | 5001 | Local registry port | Change if port conflicts |
| `MSG` | "Update" | Release commit message | `MSG="feat: new feature"` |

### Setting Variables

```bash
# Override defaults
make quickstart CLUSTER_NAME=my-cluster
make release-ghcr MSG="fix: critical bug"

# Persistent environment variables
export CLUSTER_NAME=production
export REGISTRY_PORT=5002
```

## Command Categories by Use Case

### First Time Setup

1. `cp .env.example .env` (edit Discord webhook)
2. `make quickstart` (choose local or GHCR)
3. `sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'`
4. `make access` (get URLs and credentials)
5. `kubectl top nodes` (verify resource monitoring works)

### Daily Development

1. `make develop-local` (build and deploy changes)
2. `make status` (check system health)
3. `make logs` (view ArgoCD logs if issues)

### Production Release

1. `make release-ghcr MSG="release: v1.0.0"` (full release)
2. `make release-status` (monitor CI/CD)
3. `make status` (verify deployment)

### Troubleshooting

1. `make status` (system overview)
2. `make metrics-status` (check resource monitoring)
3. `make logs` (ArgoCD logs)
4. `make resume-services` (if services paused)
5. `make clean && make quickstart` (nuclear option)

### Maintenance

1. `make pause-services` (save resources)
2. `make resume-services` (restore services)
3. `make alert-status` (check alerts)
4. `docker system prune -a` (clean space)

## Command Combinations

### Fresh Environment

```bash
# Complete setup from scratch
make clean
cp .env.example .env  # Edit Discord webhook
make quickstart-local
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'
make access
```

### Development Cycle

```bash
# After code changes
make develop-local
make status
# If issues:
make logs
```

### Resource Management

```bash
# Save resources when not developing
make pause-services

# Resume when needed
make resume-services
make status  # Verify everything is running
```

## Advanced Usage

### Custom Cluster Names

```bash
# Use custom cluster name
make quickstart CLUSTER_NAME=my-project
make status CLUSTER_NAME=my-project
make clean CLUSTER_NAME=my-project
```

### Development with Different Registry Port

```bash
# If port 5001 is in use
export REGISTRY_PORT=5002
make quickstart-local
make develop-local
```

### Batch Operations

```bash
# Multiple quick commands
make status && make logs && make access

# Conditional execution
make status || make resume-services
```

## Internal Commands

These commands are used internally by quickstart and other workflows. You typically don't need to run them manually.

### Infrastructure Setup

| Command | Description | Usage |
|---------|-------------|-------|
| `make cluster-create` | Create Kind cluster | Internal setup |
| `make cluster-delete` | Delete Kind cluster | Internal cleanup |
| `make registry-setup` | Setup local Docker registry | Internal setup |
| `make registry-test` | Test local registry connectivity | Internal validation |
| `make metrics-install` | Install metrics-server for kubectl top | Infrastructure setup |
| `make metrics-status` | Check metrics-server status | Health checking |

### ArgoCD Setup

| Command | Description | Usage |
|---------|-------------|-------|
| `make argocd-install` | Install ArgoCD | Internal setup |
| `make argocd-config` | Configure ArgoCD settings and secrets | Internal setup |
| `make ingress-install` | Install NGINX Ingress Controller | Internal setup |
| `make ingress-config` | Configure Ingress rules for ArgoCD | Internal setup |

### GHCR Workflow

| Command | Description | Usage |
|---------|-------------|-------|
| `make check-git-status` | Check for uncommitted changes | GHCR workflow |
| `make check-sync-strict` | Check sync status with strict safety checks | GHCR workflow |
| `make wait-for-actions` | Wait for GitHub Actions to complete | GHCR workflow |
| `make sync-actions-changes` | Sync changes made by GitHub Actions | GHCR workflow |

## Help & Discovery

| Command | Description | Usage |
|---------|-------------|-------|
| `make help` | Show all available commands | Command discovery |
| `make` | Show help (default target) | Quick reference |

## Common Patterns

### Check Before Action

```bash
# Always check status first
make status
# Then proceed with action
make resume-services
# Verify result
make status
```

### Safe Development

```bash
# Build and test locally first
make build-local
# If successful, then deploy
make develop-local
```

### Production Safety

```bash
# Check current status
make status
# Review changes
make release-ghcr MSG="review: check changes"
# Monitor deployment
make release-status
```

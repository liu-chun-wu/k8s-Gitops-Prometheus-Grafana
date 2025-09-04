# Development Guide

## Development Workflow Overview

This project supports two development workflows:
- **Local Development**: Fast iteration with local Docker registry
- **Production Release**: GHCR-based releases with GitHub Actions

## Local Development Workflow

### Concept

Local development uses a Docker registry running on `localhost:5001` to provide fast build-push-deploy cycles without external dependencies.

### Typical Flow

1. **Code Changes** → Modify application code
2. **Build** → Create Docker image with new changes  
3. **Push** → Upload to local registry (instant)
4. **Update Manifest** → Change image tag in Kubernetes manifest
5. **Sync** → ArgoCD detects change and deploys

### Benefits

- ⚡ **Fast cycles**: Seconds instead of minutes
- 🔒 **No external deps**: Everything runs locally
- 🛠️ **Easy debugging**: Direct access to all components

## GHCR Production Workflow  

### Concept

Production workflow uses GitHub Container Registry (GHCR) with GitHub Actions for CI/CD pipeline integration.

### Typical Flow

1. **Code Changes** → Commit changes to Git
2. **Release Command** → Triggers release process
3. **GitHub Actions** → Builds and pushes image to GHCR  
4. **Auto-update** → Actions updates Kubernetes manifest
5. **ArgoCD Sync** → Deploys new version automatically

### Benefits

- 🔄 **Complete automation**: Full CI/CD pipeline
- 📦 **Production images**: Proper image management
- 🔍 **Audit trail**: Full history in Git and GitHub

## Monitoring & Alerting Integration

### Alert System

Both workflows integrate with the monitoring stack:
- **Discord notifications** for deployment events
- **Prometheus metrics** collection  
- **Grafana dashboards** for visibility
- **AlertManager** for issue notifications

### Development Benefits

- 🔔 **Real-time feedback**: Know immediately if deployments fail
- 📊 **Performance insights**: Monitor resource usage
- 🚨 **Early warning**: Catch issues before production

## Environment Variables

Configuration options for customizing the development environment:

| Variable | Purpose | Default |
|----------|---------|---------|
| `CLUSTER_NAME` | Kubernetes cluster name | gitops-demo |
| `REGISTRY_PORT` | Local registry port | 5001 |
| `MSG` | Git commit message | "Update" |

## ArgoCD Integration

### GitOps Principles

Both workflows follow GitOps principles:
- **Git as source of truth**: All config in Git
- **Declarative**: Desired state defined in YAML
- **Automated sync**: ArgoCD monitors and applies changes
- **Audit trail**: All changes tracked in Git history

### Application Management

ArgoCD manages applications through:
- **Application manifests**: Define what to deploy
- **Kustomize overlays**: Environment-specific configs
- **Automated sync**: Continuous reconciliation
- **Health checks**: Monitor deployment status

## Commands Reference

For all development commands, see: [Make Reference - Development Workflow](./make-reference.md#development-workflow)

## Best Practices

### Local Development

1. **Start simple**: Use local workflow first
2. **Check status**: Monitor deployments with status commands
3. **View logs**: Check ArgoCD logs if issues occur
4. **Clean regularly**: Remove old Docker images

### Production Releases

1. **Test locally first**: Validate changes locally
2. **Meaningful messages**: Use descriptive commit messages
3. **Monitor releases**: Watch GitHub Actions progress
4. **Verify deployment**: Check ArgoCD and service health

### Troubleshooting

1. **Check status first**: Always start with system overview
2. **Review logs**: Look at ArgoCD and application logs
3. **Verify prerequisites**: Ensure .env file and dependencies
4. **Reference guides**: Use troubleshooting and kubectl references

## Next Steps

- **Start developing**: Begin with local workflow
- **Monitor system**: Use Grafana dashboards
- **Handle alerts**: Configure Discord notifications
- **Scale up**: Move to GHCR for production releases
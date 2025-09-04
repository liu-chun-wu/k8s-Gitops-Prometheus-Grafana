# Quick Start Guide

## Prerequisites

**Required**: Set up Discord webhook before running quickstart

```bash
cp .env.example .env
# Edit .env with your Discord webhook URL
```

## Quick Setup Flow

1. **Setup Discord webhook** (required)
2. **Choose deployment mode** 
3. **Configure local DNS**
4. **Access services**

## Step-by-Step Instructions

### 1. Discord Webhook Setup

Create webhook in Discord server:
- Server Settings → Integrations → Webhooks
- Create New Webhook → Copy URL
- Add URL to .env file

### 2. Deploy Everything

Choose your deployment mode:
- **Local development**: Uses local Docker registry
- **Production**: Uses GitHub Container Registry (GHCR)

### 3. Configure DNS

Required for ArgoCD access:

```bash
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'
```

### 4. Access Services

View all service URLs and credentials after setup completes.

## What Gets Installed

- **ArgoCD**: GitOps deployment management
- **Prometheus**: Metrics collection
- **Grafana**: Monitoring dashboards  
- **AlertManager**: Alert routing
- **Discord Integration**: Real-time notifications
- **Demo Applications**: Sample workloads

## Service Credentials

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | `http://argocd.local` | admin/admin123 |
| Grafana | `http://localhost:3001` | admin/admin123 |
| Prometheus | `http://localhost:9090` | - |
| AlertManager | `http://localhost:9093` | - |

## Commands

For all quickstart and setup commands, see: [Make Reference](./make-reference.md#setup--installation)

## Next Steps

After quickstart completes:

1. **Explore Services**: Visit the URLs above
2. **Check Status**: Monitor system health
3. **View Logs**: Check ArgoCD logs if needed
4. **Start Developing**: Begin local development workflow

## Troubleshooting

If quickstart fails:
- Ensure .env file exists with valid Discord webhook
- Check Docker Desktop is running
- Verify ports 5001, 3001, 9090, 9093 are available
- See [Troubleshooting Guide](./troubleshooting.md) for more help
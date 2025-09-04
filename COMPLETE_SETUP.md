# Complete Setup Documentation

## 📋 Overview

This document describes the enhanced setup commands that include ALL features of the project, including Discord alerting and complete monitoring stack.

## 🚀 Quick Start - Complete Edition

### Option 1: Fresh Installation with All Features

```bash
# 1. Set up Discord webhook (optional but recommended)
cp .env.example .env
# Edit .env and add your Discord webhook URL

# 2. Run complete setup
make -f Makefile.enhanced quickstart-ghcr-complete
```

This command will:

- ✅ Create Kind cluster
- ✅ Install and configure ArgoCD
- ✅ Install NGINX Ingress Controller
- ✅ Deploy GHCR application
- ✅ Deploy complete monitoring stack (Prometheus, Grafana, AlertManager)
- ✅ **Install Discord alerting system** (if .env exists)
- ✅ Apply Prometheus alert rules
- ✅ Configure all ServiceMonitors
- ✅ Show complete status including alert system

### Option 2: Upgrade Existing Setup

If you already have a running cluster:

```bash
# Migrate to complete setup
make -f Makefile.enhanced migrate-to-complete
```

## 📊 Enhanced Commands

### Complete Status Check

```bash
make -f Makefile.enhanced status-complete
```

Shows:

- ArgoCD pod status
- Complete monitoring stack status
- **Discord alerting status**
- Alert rules configuration
- Application status
- Service health checks

### Complete Resume Services

```bash
make -f Makefile.enhanced resume-services-complete
```

Resumes:

- All ArgoCD components
- All monitoring components
- **Discord alertmanager service**
- All applications
- Ingress controller

With health checks for:

- ArgoCD server and controller
- Grafana, Prometheus, AlertManager
- **Discord alerting service**
- All deployed applications

### Complete Access Information

```bash
make -f Makefile.enhanced access-complete
```

Shows:

- All service URLs
- All credentials
- **Discord webhook configuration status**
- Setup instructions for missing components

## 🔄 Comparison: Standard vs Complete

| Feature | Standard (`quickstart-ghcr`) | Complete (`quickstart-ghcr-complete`) |
|---------|------------------------------|---------------------------------------|
| Kind Cluster | ✅ | ✅ |
| ArgoCD | ✅ | ✅ |
| Ingress Controller | ✅ | ✅ |
| GHCR Application | ✅ | ✅ |
| Prometheus | ✅ | ✅ |
| Grafana | ✅ | ✅ |
| AlertManager | ✅ | ✅ |
| **Discord Alerting** | ❌ | ✅ |
| **Alert Rules** | ❌ | ✅ |
| **ServiceMonitor Validation** | ❌ | ✅ |
| **Complete Health Checks** | Partial | ✅ |

## 🔔 Discord Alerting Setup

### Prerequisites

1. Create a Discord webhook:
   - Go to Discord Server Settings → Integrations → Webhooks
   - Create New Webhook
   - Copy the webhook URL

2. Configure the webhook:

   ```bash
   cp .env.example .env
   # Edit .env and add your webhook URL
   ```

3. Install alerting (if not done by complete setup):

   ```bash
   make alert-install
   ```

### Testing Alerts

```bash
# Send instant test alert
make test-alert-instant

# Send delayed test alert (1-2 minutes)
make test-alert
```

## 🛠️ Troubleshooting

### Discord Alerting Not Working

1. Check if Discord service is running:

   ```bash
   kubectl get pods -n monitoring | grep discord
   ```

2. Check logs:

   ```bash
   kubectl logs -n monitoring deployment/alertmanager-discord
   ```

3. Verify webhook secret:

   ```bash
   kubectl get secret discord-webhook -n monitoring
   ```

### Missing Components After Resume

Run the complete resume command:

```bash
make -f Makefile.enhanced resume-services-complete
```

## 📝 Integration with Main Makefile

To make these commands available in the main Makefile:

```bash
# Add to the end of your main Makefile:
echo "include Makefile.enhanced" >> Makefile
```

Then you can use:

```bash
make quickstart-ghcr-complete
make resume-services-complete
make status-complete
```

## 🔍 Verification Checklist

After running `quickstart-ghcr-complete`, verify:

- [ ] ArgoCD accessible at <http://argocd.local>
- [ ] Grafana accessible at <http://localhost:30301>
- [ ] Prometheus accessible at <http://localhost:30090>
- [ ] AlertManager accessible at <http://localhost:30093>
- [ ] Discord webhook configured (check with `kubectl get secret discord-webhook -n monitoring`)
- [ ] Alert rules applied (check Prometheus → Alerts)
- [ ] Test alert received in Discord channel

## 📚 Additional Resources

- [Alert Management Guide](./docs/alert-management.md)
- [Monitoring Stack Details](./docs/monitoring.md)
- [Troubleshooting Guide](./docs/troubleshooting.md)

## 🤝 Contributing

When adding new features, ensure they are:

1. Added to `quickstart-ghcr-complete`
2. Included in `resume-services-complete`
3. Checked in `status-complete`
4. Documented in this file

---

*Last updated: 2024-09-03*

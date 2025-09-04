# K8s GitOps with Prometheus & Grafana

A production-ready Kubernetes GitOps demo featuring ArgoCD, Prometheus monitoring, and Grafana dashboards.

## 🚀 Quick Start

```bash
# 1. Set up Discord webhook (required)
cp .env.example .env
# Edit .env with your Discord webhook URL

# 2. Deploy everything
make quickstart        # Interactive mode selection

# 3. Configure local access
sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'

# 4. Access services
make access           # Shows URLs and credentials
```

## 📚 Documentation

### Quick References

- **[Quick Start Commands](docs/guides/quickstart.md)** - Get up and running fast
- **[Make Reference](docs/commands/make-reference.md)** - All make commands
- **[Development Commands](docs/guides/development.md)** - Build, deploy, and test
- **[Operations Commands](docs/guides/operations.md)** - Manage and troubleshoot
- **[Kubectl Reference](docs/commands/kubectl-reference.md)** - All kubectl commands
- **[Monitoring Reference](docs/guides/monitoring-reference.md)** - Metrics and queries
- **[Troubleshooting Guide](docs/guides/troubleshooting.md)** - Fix common issues

### Detailed Guides
- **[Architecture Overview](docs/guides/architecture.md)** - System design and components
- **[Local Development Setup](docs/guides/local-setup.md)** - Complete local environment guide
- **[GHCR Production Setup](docs/guides/ghcr-setup.md)** - GitHub Container Registry deployment
- **[ArgoCD & GitOps Workflow](docs/guides/argocd-gitops.md)** - GitOps principles and practices
- **[Monitoring Stack](docs/guides/monitoring-stack.md)** - Prometheus and Grafana deep dive
- **[Alerting System](docs/guides/alerting-system.md)** - Discord/Slack alert configuration

## 🌐 Service Access

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | <http://argocd.local> | admin/admin123 |
| Grafana | <http://localhost:30301> | admin/admin123 |
| Prometheus | <http://localhost:30090> | - |
| AlertManager | <http://localhost:30093> | - |

## ✨ Features

- **GitOps Deployment** - Automated deployments via ArgoCD
- **Dual Registry Support** - Local development and GHCR production
- **Complete Monitoring** - Prometheus, Grafana, and AlertManager
- **Discord Alerting** - Real-time notifications
- **One-Command Setup** - Simplified deployment process

## 📋 Prerequisites

- Docker Desktop
- Kind (`brew install kind`)
- kubectl (`brew install kubectl`)
- Make (pre-installed on macOS/Linux)

## 🏗️ Project Structure

```
├── .github/             # GitHub Actions workflows
├── clusters/            # Kind cluster definitions
├── docs/
│   ├── commands/        # Quick command references (kubectl, make)
│   └── guides/          # Detailed explanations and workflows
├── gitops/              # ArgoCD applications
├── ingress/             # Ingress controller configurations
├── k8s/                 # Kubernetes manifests
├── monitoring/          # Prometheus & Grafana configs
├── scripts/             # Automation scripts
├── Dockerfile           # Container image definition
└── Makefile             # Build and deployment automation
```

## ⚠️ Security Note

This project uses fixed passwords for demo purposes. For production use, implement proper secret management with tools like Sealed Secrets or External Secrets Operator.

## 📄 License

MIT License - See LICENSE file for details

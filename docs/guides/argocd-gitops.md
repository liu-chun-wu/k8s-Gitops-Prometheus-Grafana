# ArgoCD & GitOps Workflow Guide

## Understanding GitOps

### Core Concepts

GitOps is a way of implementing Continuous Deployment for cloud native applications. It focuses on a developer-centric experience when operating infrastructure, by using tools developers are already familiar with, including Git and Continuous Deployment tools.

**Four Core Principles:**

1. **Declarative**: The entire system is described declaratively
2. **Versioned and Immutable**: The canonical desired system state is versioned in Git
3. **Pulled Automatically**: Approved changes are automatically applied to the system
4. **Continuously Reconciled**: Software agents ensure correctness and alert on divergence

### GitOps vs Traditional CI/CD

| Aspect | Traditional CI/CD | GitOps |
|--------|------------------|---------|
| Deployment | Push-based | Pull-based |
| Source of Truth | CI/CD Pipeline | Git Repository |
| Credentials | CI needs cluster access | Cluster pulls from Git |
| Rollback | Re-run pipeline | Git revert |
| Audit Trail | CI/CD logs | Git history |
| Access Control | Multiple systems | Git permissions |

## ArgoCD Architecture

### Components

```
┌─────────────────────────────────────────┐
│           ArgoCD Server (API/UI)         │
├─────────────────────────────────────────┤
│         Application Controller           │
│    (Monitors apps, reconciles state)    │
├─────────────────────────────────────────┤
│           Repo Server                    │
│    (Manages Git repos, renders manifests)│
├─────────────────────────────────────────┤
│              Redis                       │
│         (Caching and state)             │
├─────────────────────────────────────────┤
│               Dex                        │
│         (OIDC authentication)           │
└─────────────────────────────────────────┘
```

### How ArgoCD Works

1. **Connect Repository**: ArgoCD connects to your Git repository
2. **Define Application**: Create an Application resource pointing to your manifests
3. **Monitor Changes**: ArgoCD continuously monitors Git for changes
4. **Compare State**: Compares desired state (Git) with live state (cluster)
5. **Sync Differences**: Applies changes to make cluster match Git
6. **Report Status**: Shows sync status and health in UI

## Installation and Configuration

### Installing ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Initial Configuration

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward for UI access
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login with CLI
argocd login localhost:8080 --username admin --password <initial-password>

# Change admin password
argocd account update-password
```

### Setting Up Repository

```bash
# Add repository (public)
argocd repo add https://github.com/username/k8s-configs

# Add repository (private with SSH)
argocd repo add git@github.com:username/k8s-configs.git --ssh-private-key-path ~/.ssh/id_rsa

# Add repository (private with token)
argocd repo add https://github.com/username/k8s-configs --username <username> --password <token>

# List repositories
argocd repo list
```

## Creating Applications

### Declarative Application Definition

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/username/k8s-configs
    targetRevision: main
    path: k8s/podinfo/overlays/production
    
    # For Helm charts
    # helm:
    #   releaseName: podinfo
    #   valueFiles:
    #     - values-prod.yaml
    
    # For Kustomize
    # kustomize:
    #   namePrefix: prod-
    #   images:
    #     - ghcr.io/username/app:v1.0.0
  
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Sync when cluster deviates
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### CLI Application Creation

```bash
# Create application
argocd app create podinfo \
  --repo https://github.com/username/k8s-configs \
  --path k8s/podinfo/overlays/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace production \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Get application info
argocd app get podinfo

# Sync application
argocd app sync podinfo

# Delete application
argocd app delete podinfo
```

## Sync Strategies

### Manual Sync

Best for production environments requiring approval:

```yaml
syncPolicy:
  # No automated section means manual sync
  syncOptions:
    - CreateNamespace=true
```

```bash
# Manual sync via CLI
argocd app sync podinfo

# Manual sync via UI
# Click "SYNC" button in ArgoCD UI
```

### Automated Sync

Best for development environments:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
    allowEmpty: false
```

### Selective Sync

Sync only specific resources:

```bash
# Sync only deployments
argocd app sync podinfo --resource apps:Deployment

# Sync specific resource
argocd app sync podinfo --resource apps:Deployment:podinfo
```

## Advanced Features

### App of Apps Pattern

Manage multiple applications with a parent app:

```yaml
# apps/parent-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/username/k8s-configs
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### ApplicationSets

Generate multiple applications from a template:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-apps
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: staging
        url: https://staging.k8s.local
      - cluster: production
        url: https://prod.k8s.local
  template:
    metadata:
      name: '{{cluster}}-app'
    spec:
      project: default
      source:
        repoURL: https://github.com/username/k8s-configs
        targetRevision: main
        path: 'k8s/{{cluster}}'
      destination:
        server: '{{url}}'
        namespace: apps
```

### Sync Waves and Hooks

Control deployment order:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"    # Deploy first
    argocd.argoproj.io/hook: PreSync     # Run before sync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

Waves example:
- Wave -2: Namespaces, CRDs
- Wave -1: ConfigMaps, Secrets
- Wave 0: Deployments, Services
- Wave 1: Ingress
- Wave 2: Post-deployment tests

### Health Checks

Custom health checks:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.health.argoproj.io_Application: |
    hs = {}
    hs.status = "Progressing"
    hs.message = ""
    if obj.status ~= nil then
      if obj.status.health ~= nil then
        hs.status = obj.status.health.status
        hs.message = obj.status.health.message
      end
    end
    return hs
```

## Project Management

### Creating Projects

Projects provide logical grouping and RBAC:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications
  
  sourceRepos:
  - 'https://github.com/username/*'
  
  destinations:
  - namespace: 'prod-*'
    server: https://kubernetes.default.svc
  
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
  
  roles:
  - name: developers
    policies:
    - p, proj:production:developers, applications, get, production/*, allow
    - p, proj:production:developers, applications, sync, production/*, allow
    groups:
    - my-org:developers
```

## Secrets Management

### Sealed Secrets Integration

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Install kubeseal
brew install kubeseal

# Create sealed secret
echo -n mypassword | kubectl create secret generic mysecret --dry-run=client --from-file=password=/dev/stdin -o yaml | kubeseal -o yaml > sealedsecret.yaml

# Commit sealed secret to Git
git add sealedsecret.yaml
git commit -m "Add sealed secret"
git push
```

### External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: vault-secret
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secret
  data:
  - secretKey: password
    remoteRef:
      key: secret/data/database
      property: password
```

## Monitoring ArgoCD

### Prometheus Metrics

```yaml
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
```

Key metrics:
- `argocd_app_health_total`: Application health status
- `argocd_app_sync_total`: Sync operations count
- `argocd_git_request_duration_seconds`: Git operation latency
- `argocd_kubectl_exec_pending`: Pending kubectl operations

### Notifications

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  template.app-deployed: |
    message: |
      {{.app.metadata.name}} is now running new version.
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
      send: [app-deployed]
```

## Rollback Strategies

### Git-based Rollback

```bash
# Revert commit
git revert HEAD
git push

# Or reset to previous commit
git reset --hard HEAD^
git push --force

# ArgoCD will automatically sync
```

### ArgoCD Rollback

```bash
# View history
argocd app history podinfo

# Rollback to revision
argocd app rollback podinfo 2

# Rollback via UI
# Click "HISTORY AND ROLLBACK" in app details
```

## Best Practices

### Repository Structure

```
k8s-configs/
├── apps/                 # Application definitions
│   ├── staging/
│   └── production/
├── base/                 # Base manifests
│   ├── namespace.yaml
│   └── rbac.yaml
├── overlays/            # Environment overlays
│   ├── staging/
│   └── production/
└── clusters/            # Cluster-specific configs
    ├── cluster-1/
    └── cluster-2/
```

### Security Best Practices

1. **Use Projects**: Limit repository and namespace access
2. **RBAC**: Configure proper role-based access
3. **Secrets Management**: Never commit plain secrets
4. **Git Branch Protection**: Require PR reviews
5. **Resource Limits**: Set resource quotas
6. **Network Policies**: Restrict pod communication
7. **Audit Logging**: Enable and monitor audit logs

### Operational Best Practices

1. **Start Manual**: Begin with manual sync, automate gradually
2. **Use Staging**: Test changes in staging first
3. **Monitor Metrics**: Set up alerts for sync failures
4. **Document Everything**: Clear README files
5. **Version Everything**: Use semantic versioning
6. **Backup State**: Regular etcd backups
7. **Plan Disaster Recovery**: Document recovery procedures

## Troubleshooting

### Common Issues

#### Application Stuck in Progressing

```bash
# Check application details
argocd app get <app-name>

# Check events
kubectl get events -n <namespace>

# Force sync
argocd app sync <app-name> --force
```

#### Sync Failed

```bash
# Check sync status
argocd app get <app-name> --refresh

# View diff
argocd app diff <app-name>

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller
```

#### Repository Not Accessible

```bash
# Test repository connection
argocd repo get <repo-url>

# Re-add repository
argocd repo rm <repo-url>
argocd repo add <repo-url> --username <user> --password <token>
```

## Next Steps

- Implement [monitoring](./monitoring-stack.md) for ArgoCD
- Set up [alerting](./alerting-system.md) for sync failures
- Configure [GHCR](./ghcr-setup.md) for image management
- Explore [local development](./local-setup.md) workflow
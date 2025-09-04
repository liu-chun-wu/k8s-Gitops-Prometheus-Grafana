# Kubectl Command Reference

## Basic Operations

### Pod Management

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl get pods -A` | List all pods in cluster | Overview |
| `kubectl get pods -n <namespace>` | List pods in namespace | Specific namespace |
| `kubectl get pods -A -o wide` | Detailed pod information | With node info |
| `kubectl describe pod <pod> -n <ns>` | Pod details and events | Debugging |
| `kubectl logs <pod> -n <ns>` | View pod logs | Error analysis |
| `kubectl logs <pod> -n <ns> --previous` | Previous container logs | After crash |
| `kubectl exec -it <pod> -n <ns> -- sh` | Shell into pod | Interactive debug |
| `kubectl delete pod <pod> -n <ns>` | Delete pod | Force restart |

### Application Management

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl get apps -n argocd` | List ArgoCD applications | Check sync status |
| `kubectl delete app <app> -n argocd` | Remove ArgoCD app | Cleanup |
| `kubectl patch app <app> -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'` | Force refresh | Sync issues |

### Deployment Operations

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl rollout restart deployment -n <ns>` | Restart deployment | Force update |
| `kubectl scale deployment <name> --replicas=N -n <ns>` | Scale deployment | Change replicas |
| `kubectl rollout status deployment/<name> -n <ns>` | Check rollout status | Monitor update |

## Resource Monitoring

### Resource Usage

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl top nodes` | Node resource usage | CPU/Memory |
| `kubectl top pods -A` | All pods resource usage | Cluster-wide |
| `kubectl top pods -n <namespace>` | Namespace pod resources | Specific namespace |

### Events & Status

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl get events -A --sort-by='.lastTimestamp'` | All recent events | Timeline view |
| `kubectl get events -n <ns> --sort-by='.lastTimestamp'` | Namespace events | Specific namespace |
| `kubectl get events -A --field-selector type=Warning` | Warning events only | Issues only |

## Networking

### Service Discovery

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl get svc -A` | List all services | Overview |
| `kubectl get svc -n <namespace>` | Namespace services | Specific namespace |
| `kubectl get endpoints -n <namespace>` | Service endpoints | Backend pods |
| `kubectl get ingress -A` | List all ingresses | External access |

### Network Debugging

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl port-forward svc/<service> <local>:<remote> -n <ns>` | Port forwarding | Local access |
| `kubectl exec -it <pod> -- curl <service>:<port>` | Test connectivity | Service check |
| `kubectl exec -it <pod> -- nslookup <service>` | DNS resolution | DNS debug |
| `kubectl get networkpolicy -A` | Network policies | Access rules |

## Troubleshooting

### Quick Diagnosis

```bash
# Show all non-running pods
kubectl get pods -A | grep -v Running | grep -v Completed

# Recent warning events
kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -20

# Check all namespaces
for ns in argocd monitoring demo-local demo-ghcr; do 
  echo "=== $ns ==="
  kubectl get pods -n $ns
done
```

### Common Issues

| Issue | Command | Purpose |
|-------|---------|---------|
| Pod CrashLoop | `kubectl describe pod <pod> -n <ns>` | View events |
| | `kubectl logs <pod> -n <ns> --previous` | Previous logs |
| Service Down | `kubectl get endpoints -n <ns>` | Check backends |
| | `kubectl get svc -n <ns>` | Service status |
| High Resource | `kubectl top pods -n <ns>` | Resource usage |
| | `kubectl describe nodes` | Node pressure |

## Namespace Operations

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl get ns` | List namespaces | Overview |
| `kubectl create ns <name>` | Create namespace | New namespace |
| `kubectl delete ns <name>` | Delete namespace | Remove all resources |
| `kubectl get all -n <namespace>` | All resources in namespace | Quick overview |

## Secret Management

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl get secrets -n <ns>` | List secrets | Overview |
| `kubectl describe secret <name> -n <ns>` | Secret details | Without values |
| `kubectl get secret <name> -n <ns> -o yaml` | Full secret | Base64 encoded |
| `kubectl create secret generic <name> --from-literal=key=value -n <ns>` | Create secret | New secret |

## Specific Restart Commands

### By Namespace

| Command | Description |
|---------|-------------|
| `kubectl rollout restart deployment -n argocd` | Restart ArgoCD |
| `kubectl rollout restart deployment -n monitoring` | Restart monitoring stack |
| `kubectl rollout restart deployment -n demo-local` | Restart local apps |
| `kubectl rollout restart deployment -n demo-ghcr` | Restart GHCR apps |
| `kubectl delete pods --all -n <namespace>` | Force restart all pods |

## Monitoring Specific

### Alert System

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl get secret discord-webhook -n monitoring` | Check Discord secret | Verify setup |
| `kubectl logs -n monitoring deployment/alertmanager-discord` | Discord adapter logs | Debug alerts |
| `kubectl logs -n monitoring alertmanager-<pod>` | AlertManager logs | Alert routing |

### Testing Scenarios

| Command | Description | Duration |
|---------|-------------|----------|
| `kubectl scale deployment ghcr-podinfo --replicas=0 -n demo-ghcr` | Trigger PodDown alert | ~1 minute |
| `kubectl scale deployment ghcr-podinfo --replicas=2 -n demo-ghcr` | Restore service | Immediate |

## Debug Utilities

### Interactive Debugging

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl run debug --image=busybox -it --rm` | Temporary debug pod | Network testing |
| `kubectl run curl --image=curlimages/curl -it --rm -- sh` | Curl testing pod | API testing |
| `kubectl run memory-stress --image=polinux/stress --rm -it -- stress --vm 1 --vm-bytes 500M --timeout 60s` | Memory stress test | Load testing |

## API Access

### Direct API Calls

| Command | Description | Usage |
|---------|-------------|-------|
| `kubectl proxy` | Start API proxy | Local API access |
| `kubectl api-resources` | List all resource types | Available APIs |
| `kubectl explain <resource>` | Resource documentation | Field details |

### Using curl with kubectl proxy

```bash
# Start proxy in background
kubectl proxy &

# Access API
curl http://localhost:8001/api/v1/namespaces
curl http://localhost:8001/api/v1/namespaces/default/pods
```

## Useful Aliases

Add to your shell profile:

```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias klog='kubectl logs'
alias kexec='kubectl exec -it'
```

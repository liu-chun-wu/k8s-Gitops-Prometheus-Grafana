# Troubleshooting Guide

## Common Issues & Solutions

### ArgoCD Not Accessible

**Problem**: Cannot reach ArgoCD UI
**Diagnosis**: 
- Check if ingress exists
- Verify /etc/hosts entry
- Check ArgoCD pod status

**Solutions**:
- Add hostname: `sudo sh -c 'echo "127.0.0.1 argocd.local" >> /etc/hosts'`
- See [kubectl reference](./kubectl-reference.md#troubleshooting) for pod commands

### Application OutOfSync

**Problem**: ArgoCD app shows OutOfSync
**Diagnosis**:
- Check application status
- Compare Git vs cluster state

**Solutions**:
- `argocd app sync <app-name>` - Manual sync
- Force refresh with kubectl (see [kubectl reference](./kubectl-reference.md))

### Pod CrashLoopBackOff

**Problem**: Pod keeps restarting
**Diagnosis Steps**:
1. Check pod events
2. View current and previous logs  
3. Check resource limits
4. Verify image availability

**Solutions**:
- Fix configuration issues
- Increase resource limits
- Check image pull secrets
- See [kubectl reference](./kubectl-reference.md#troubleshooting) for commands

### Service Not Responding

**Problem**: Service unreachable
**Diagnosis**:
- Check service endpoints
- Verify pod readiness
- Test service connectivity

**Solutions**:
- Fix pod health checks
- Check port configuration
- Verify service selectors
- See [kubectl reference](./kubectl-reference.md#networking) for commands

### Monitoring Issues

| Problem | Likely Cause | Solution |
|---------|--------------|----------|
| No metrics | Targets down | Check [kubectl reference](./kubectl-reference.md#monitoring-specific) |
| Grafana login fails | Wrong credentials | Use admin/admin123 or check secret |
| AlertManager silent | Config error | Check AlertManager logs |
| Discord not receiving | Webhook issue | Verify secret and logs |

### Resource Issues

**High CPU/Memory**:
- Check resource usage with `kubectl top`
- Identify resource-heavy pods
- Scale or add resource limits

**Disk Space Low**:
- Clean Docker cache: `docker system prune -a`
- Check persistent volumes
- Remove unused images

### Network Debugging

**DNS Issues**:
- Test DNS resolution from pods
- Check CoreDNS status
- Verify service discovery

**Connectivity Problems**:
- Test pod-to-pod communication
- Check network policies
- Verify service endpoints

For specific network debugging commands, see [kubectl reference](./kubectl-reference.md#networking).

## Cluster Recovery Strategies

### Severity Levels

| Level | Action | Command |
|-------|--------|---------|
| **Minor** | Restart services | See [Make Reference](./make-reference.md) |
| **Major** | Recreate pods | See kubectl reference for pod deletion |
| **Critical** | Restart cluster node | `docker restart gitops-demo-control-plane` |
| **Nuclear** | Full rebuild | See [Make Reference](./make-reference.md) |

## Quick Diagnosis Commands

For comprehensive command lists, see [kubectl reference](./kubectl-reference.md#quick-diagnosis).

## Log Collection

**Application Logs**:
- ArgoCD: See [Make Reference](./make-reference.md)
- Application pods: See [kubectl reference](./kubectl-reference.md#pod-management)

**System Logs**:
- Node events: See [kubectl reference](./kubectl-reference.md#events--status)
- Container logs: See [kubectl reference](./kubectl-reference.md#pod-management)

## Performance Debugging

**Resource Monitoring**:
- Use `kubectl top` commands (see [kubectl reference](./kubectl-reference.md#resource-usage))
- Check node pressure
- Monitor pod resource consumption

**Network Performance**:
- Test connectivity between services
- Check DNS resolution times
- Monitor ingress response times

## Recovery Procedures

### Service Recovery
1. Check service status (see [Make Reference](./make-reference.md))
2. Review logs for errors
3. Restart affected services
4. Verify health after restart

### Data Recovery
- Persistent volumes are preserved during pod restarts
- ConfigMaps and secrets persist
- For complete recovery procedures, see [Make Reference](./make-reference.md)

## Getting Help

- Check [kubectl reference](./kubectl-reference.md) for all kubectl commands
- Check [Make Reference](./make-reference.md) for all make commands
- Review [operations guide](./operations.md) for routine tasks
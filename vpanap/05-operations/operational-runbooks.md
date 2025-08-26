# VPA-NAP Integration Operational Runbooks

## Quick Reference
- **Emergency Contacts**: platform-oncall@company.com
- **Escalation**: platform-engineering-lead@company.com
- **Dashboard**: https://monitoring.company.com/d/vpa-nap/overview
- **Kill Switch**: `kubectl patch deployment vpa-nap-coordinator -n platform --patch '{"spec":{"replicas":0}}'`

## Table of Contents
1. [Common Issues and Solutions](#common-issues-and-solutions)
2. [Emergency Procedures](#emergency-procedures)
3. [Monitoring and Alerting](#monitoring-and-alerting)
4. [Maintenance Tasks](#maintenance-tasks)
5. [Debugging Commands](#debugging-commands)

---

## Common Issues and Solutions

### Issue 1: VPA-NAP Conflict Detected (Circuit Breaker Triggered)

**Symptoms:**
- Alert: `VPANAPConflictDetected`
- VPAs switching to `updateMode: Off`
- Cluster node count fluctuating

**Diagnosis:**
```bash
# Check recent conflicts
kubectl get vpanapcoordinations --all-namespaces -o wide

# Check coordinator logs
kubectl logs -n platform deployment/vpa-nap-coordinator -f

# Check recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -E 'VPA|NAP|Evicted|ScaleUp'
```

**Resolution:**
```bash
# 1. Verify conflict is resolved
kubectl get nodes -w  # Watch for node stability

# 2. Clear circuit breaker (if stable)
kubectl get vpanapcoordinations --all-namespaces -o name | \
  xargs -I {} kubectl patch {} --type merge --patch '{"status":{"phase":"Active","circuitBreakerTriggered":false,"cooldownUntil":null}}'

# 3. Re-enable VPAs gradually (start with dev)
kubectl get vpa -n tenant-dev-* -o name | \
  xargs -I {} kubectl patch {} --type merge --patch '{"spec":{"updatePolicy":{"updateMode":"Initial"}}}'
```

**Prevention:**
- Monitor tenant resource usage patterns
- Adjust circuit breaker thresholds based on cluster size
- Implement gradual rollout for new tenants

---

### Issue 2: VPA Recommendations Drifting

**Symptoms:**
- Alert: `VPARecommendationDrift`
- Container resources not matching recommendations
- Poor application performance

**Diagnosis:**
```bash
# Check VPA status
kubectl describe vpa <VPA_NAME> -n <NAMESPACE>

# Compare recommendations vs actual usage
kubectl top pods -n <NAMESPACE> --containers

# Check VPA history
kubectl get vpanapcoordination <VPA_NAME> -n <NAMESPACE> -o yaml
```

**Resolution:**
```bash
# 1. Force VPA update (if safe)
kubectl delete pods -n <NAMESPACE> -l app=<APP_NAME>

# 2. Adjust VPA bounds if recommendations are unrealistic
kubectl patch vpa <VPA_NAME> -n <NAMESPACE> --type merge --patch '{
  "spec": {
    "resourcePolicy": {
      "containerPolicies": [{
        "containerName": "*",
        "maxAllowed": {"cpu": "4", "memory": "8Gi"}
      }]
    }
  }
}'

# 3. Reset VPA if completely off-track
kubectl delete vpa <VPA_NAME> -n <NAMESPACE>
# Recreate with conservative settings
```

---

### Issue 3: Node Pool Imbalance

**Symptoms:**
- Uneven distribution across node pools
- Some pools heavily utilized, others idle
- Cost efficiency alerts

**Diagnosis:**
```bash
# Check node utilization by pool
kubectl get nodes -o custom-columns="NAME:.metadata.name,POOL:.metadata.labels.node-pool,CPU-REQ:.status.allocatable.cpu,MEM-REQ:.status.allocatable.memory"

# Check pod distribution
kubectl get pods --all-namespaces -o wide | awk '{print $8}' | sort | uniq -c
```

**Resolution:**
```bash
# 1. Review node affinity rules
kubectl get deployments --all-namespaces -o yaml | grep -A 10 nodeSelector

# 2. Drain underutilized nodes
kubectl drain <NODE_NAME> --ignore-daemonsets --delete-emptydir-data

# 3. Update Deployment node selectors if needed
kubectl patch deployment <DEPLOYMENT_NAME> -n <NAMESPACE> --patch '{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {"node-pool": "balanced-pool"}
      }
    }
  }
}'
```

---

### Issue 4: Coordinator Pod CrashLooping

**Symptoms:**
- Coordinator pod restart count increasing
- No coordination happening
- VPAs stuck in various states

**Diagnosis:**
```bash
# Check coordinator pod status
kubectl get pods -n platform -l app=vpa-nap-coordinator

# Get detailed logs
kubectl logs -n platform -l app=vpa-nap-coordinator --previous

# Check resource constraints
kubectl describe pod -n platform -l app=vpa-nap-coordinator
```

**Resolution:**
```bash
# 1. Check ConfigMap integrity
kubectl get configmap vpa-nap-coordinator-scripts -n platform -o yaml

# 2. Increase resources if needed
kubectl patch deployment vpa-nap-coordinator -n platform --patch '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "coordinator",
          "resources": {
            "limits": {"cpu": "1", "memory": "512Mi"},
            "requests": {"cpu": "200m", "memory": "256Mi"}
          }
        }]
      }
    }
  }
}'

# 3. Force restart
kubectl rollout restart deployment/vpa-nap-coordinator -n platform
```

---

## Emergency Procedures

### Level 1: Immediate VPA Disable (< 30 seconds)

**Trigger:** Any active conflict causing resource oscillation

```bash
# Disable all VPAs with coordination
kubectl get vpa --all-namespaces -l nap-coordination=coordinated -o name | \
  xargs -I {} kubectl patch {} --type merge --patch '{"spec":{"updatePolicy":{"updateMode":"Off"}}}'

# Stop coordinator
kubectl scale deployment vpa-nap-coordinator -n platform --replicas=0
```

### Level 2: Workload Stabilization (< 5 minutes)

**Trigger:** Continued instability, pod eviction storms

```bash
# Scale up critical workloads
kubectl get deployments -n tenant-premium-* -o name | \
  xargs -I {} kubectl scale {} --replicas=3

# Remove resource limits temporarily (premium tenants only)
kubectl get deployments -n tenant-premium-* -o name | \
  xargs -I {} kubectl patch {} --type json --patch='[
    {"op": "remove", "path": "/spec/template/spec/containers/0/resources/limits"}
  ]'
```

### Level 3: Complete Rollback (< 15 minutes)

**Trigger:** System-wide impact, multiple tenant failures

```bash
# Delete all VPAs
kubectl delete vpa --all --all-namespaces

# Rollback deployments to last known good
kubectl get deployments --all-namespaces -o name | \
  xargs -I {} kubectl rollout undo {}

# Disable NAP temporarily (if needed)
kubectl patch nodepool <NODE_POOL_NAME> --type merge --patch '{"spec":{"autoscaling":{"enabled":false}}}'
```

---

## Monitoring and Alerting

### Key Metrics to Monitor

```promql
# VPA-NAP Conflict Rate
rate(vpa_nap_conflicts_total[5m])

# Node Churn Rate  
rate(cluster_autoscaler_nodes_count[1h])

# VPA Eviction Rate
rate(vpa_updater_evictions_total[5m])

# Resource Recommendation Drift
abs((vpa_recommendation - container_memory_usage_bytes) / container_memory_usage_bytes) * 100
```

### Critical Alerts

1. **VPANAPConflictDetected** (Critical)
   - Threshold: > 3 conflicts in 10 minutes
   - Action: Trigger circuit breaker

2. **NodeChurnHigh** (Warning)
   - Threshold: > 10% nodes changed in 1 hour
   - Action: Review scaling policies

3. **VPARecommendationDrift** (Warning)
   - Threshold: > 50% drift from actual usage
   - Action: Review VPA configuration

### Dashboard Queries

```bash
# Get coordination status for all VPAs
kubectl get vpanapcoordinations --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,CONFLICTS:.status.conflictsDetected,LAST_UPDATE:.status.lastUpdate"

# Check circuit breaker status
kubectl get vpanapcoordinations --all-namespaces -o json | jq '.items[] | select(.status.circuitBreakerTriggered == true) | {namespace: .metadata.namespace, name: .metadata.name, cooldownUntil: .status.cooldownUntil}'
```

---

## Maintenance Tasks

### Daily Tasks
```bash
# Check coordinator health
kubectl get pods -n platform -l app=vpa-nap-coordinator

# Review conflict count
kubectl get vpanapcoordinations --all-namespaces -o json | jq '[.items[].status.conflictsDetected] | add'

# Check resource drift
kubectl get vpa --all-namespaces -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,MODE:.spec.updatePolicy.updateMode"
```

### Weekly Tasks
```bash
# Clean up old coordination resources
kubectl get vpanapcoordinations --all-namespaces -o json | jq '.items[] | select(.metadata.creationTimestamp < (now - 86400*7 | todate)) | {namespace: .metadata.namespace, name: .metadata.name}'

# Review tenant resource usage patterns
kubectl top pods --all-namespaces --sort-by=memory

# Update coordination thresholds based on cluster growth
```

### Monthly Tasks
```bash
# Review and update circuit breaker thresholds
# Analyze cost impact of VPA recommendations
# Update tenant tier resource limits
# Review and update emergency procedures
```

---

## Debugging Commands

### Cluster State Analysis
```bash
# Get overall cluster resource utilization
kubectl top nodes

# Check NAP status (Azure specific)
az aks nodepool list --resource-group <RG> --cluster-name <CLUSTER> --query '[].{name:name,vmSize:vmSize,count:count,maxCount:maxPods}'

# VPA checkpoint data
kubectl get verticalpodautoscalercheckpoints --all-namespaces
```

### Tenant Analysis
```bash
# Get tenant resource quotas
kubectl get resourcequotas --all-namespaces

# Check tenant VPA configurations
kubectl get vpa --all-namespaces -l tenant-tier=premium

# Tenant-specific events
kubectl get events -n <TENANT_NAMESPACE> --sort-by='.lastTimestamp'
```

### Performance Analysis
```bash
# Check coordinator performance
kubectl top pod -n platform -l app=vpa-nap-coordinator

# Memory usage by tenant
kubectl top pods --all-namespaces --sort-by=memory | grep tenant-

# CPU usage patterns
kubectl top pods --all-namespaces --sort-by=cpu | head -20
```

---

## Escalation Procedures

### Level 1 Support (Platform Team)
- Monitor alerts and basic troubleshooting
- Apply standard runbook procedures
- Escalate if issue persists > 15 minutes

### Level 2 Support (Senior Platform Engineers)
- Complex configuration changes
- Coordination with Azure support
- Approve emergency procedures (Level 2-3)

### Level 3 Support (Platform Architecture Team)
- System-wide design changes
- Major incident response
- Post-incident analysis and improvements

### Contact Information
- **Platform Team**: platform-oncall@company.com
- **Senior Engineers**: platform-senior@company.com  
- **Architecture Team**: platform-architecture@company.com
- **Emergency Hotline**: +1-555-PLATFORM

---

## Post-Incident Procedures

### Immediate (< 1 hour)
1. Document incident timeline
2. Preserve logs and metrics
3. Notify affected tenants
4. Implement temporary workarounds

### Short-term (< 24 hours)
1. Complete detailed incident report
2. Identify root cause
3. Implement permanent fix
4. Update monitoring/alerting

### Long-term (< 1 week)
1. Conduct post-incident review
2. Update runbooks and procedures
3. Implement preventive measures
4. Share learnings with team

**Incident Report Template:** https://wiki.company.com/vpa-nap-incident-template
# 04-infrastructure: High Availability and Infrastructure

## Overview

This directory contains infrastructure configurations for production deployment including high availability setup, node pool strategies, and tenant-specific VPA policies.

## Components

### High Availability
- **high-availability.yaml**: HA coordinator deployment with leader election and multi-zone support

### Node Management  
- **node-pool-strategy.yaml**: Node pool configuration and VPA-NAP coordination strategies

### Tenant Policies
- **tenant-vpa-policies.yaml**: Tenant-specific VPA configurations and policies

## Deployment

Deploy after foundation, policies, and monitoring:

```bash
# Deploy infrastructure configurations
kubectl apply -f 04-infrastructure/

# Verify HA deployment
kubectl get deployment vpa-nap-coordinator-ha -n platform
kubectl get pods -n platform -l app=vpa-nap-coordinator

# Check leader election
kubectl get lease vpa-nap-coordinator -n platform
```

## High Availability Features

### Leader Election
- **Kubernetes Leases**: Native leader election mechanism
- **Multi-Replica**: 3 replicas with anti-affinity rules
- **Graceful Failover**: Automatic leader transition on failures
- **Split-Brain Protection**: Prevents multiple active coordinators

### Multi-Zone Deployment
```yaml
# Pod distribution across availability zones
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
```

### Resource Scaling
- **HPA**: Scales 3-5 replicas based on CPU/memory usage
- **PDB**: Maintains minimum 1 replica during disruptions
- **Resource Requests**: Guaranteed resources for reliability

## Node Pool Strategy

### Pool Types
1. **VPA-Dedicated Pools**: `vpa-*` - Isolated for VPA-managed workloads
2. **NAP-Managed Pools**: `nap-*` - Standard NAP-controlled scaling
3. **Hybrid Pools**: `hybrid-*` - Coordinated VPA-NAP operation
4. **System Pools**: `system-*` - Platform components only

### Coordination Strategies

#### Isolated Strategy
```yaml
# VPA workloads on dedicated nodes
nodeSelector:
  node-pool: "vpa-dedicated"
tolerations:
- key: "vpa-managed"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

#### Coordinated Strategy  
```yaml
# VPA with NAP coordination delays
coordination:
  afterVPAUpdate: "300s"    # Wait 5min after VPA change
  beforeNAPAction: "600s"   # Wait 10min before NAP scaling
```

## Tenant Configuration

### Development Tier
```yaml
tenant-dev-*:
  vpa:
    updateMode: "Auto"          # Aggressive optimization
    maxCPU: "2"
    maxMemory: "4Gi"
    coordinationStrategy: "coordinated"
  nodePool: "dev-shared"
  monitoring: "basic"
```

### Standard Tier
```yaml
tenant-std-*:
  vpa:
    updateMode: "Initial"       # Conservative approach
    maxCPU: "8" 
    maxMemory: "16Gi"
    coordinationStrategy: "isolated"
  nodePool: "standard-shared"
  monitoring: "full"
```

### Premium Tier
```yaml
tenant-premium-*:
  vpa:
    updateMode: "Off"           # Manual recommendations only
    maxCPU: "32"
    maxMemory: "64Gi" 
    coordinationStrategy: "isolated"
  nodePool: "premium-dedicated"
  monitoring: "enhanced"
```

## Circuit Breaker Configuration

### Tenant-Specific Thresholds
```yaml
circuitBreaker:
  dev:
    nodeChurnPerHour: 10        # Higher tolerance
    evictionRatePerMinute: 10
    cooldownMinutes: 15
    
  standard:
    nodeChurnPerHour: 5         # Balanced
    evictionRatePerMinute: 5  
    cooldownMinutes: 30
    
  premium:
    nodeChurnPerHour: 2         # Very conservative
    evictionRatePerMinute: 2
    cooldownMinutes: 60
```

## Backup and Recovery

### VPA State Backup
- **VPA Checkpoints**: Automated backup every 6 hours
- **Multi-Zone Replication**: Cross-region backup for disaster recovery
- **Point-in-Time Recovery**: Restore to specific checkpoint

**Note**: Using existing cluster backup framework - VPA state backup only

### Disaster Recovery
```bash
# Restore VPA state from backup
kubectl create job --from=cronjob/vpa-checkpoint-backup restore-$(date +%s) -n platform

# Verify restoration
kubectl get verticalpodautoscalercheckpoints --all-namespaces
```

## Verification Steps

### 1. HA Deployment Check
```bash
# Verify 3 replicas running
kubectl get deployment vpa-nap-coordinator-ha -n platform

# Check pod distribution
kubectl get pods -n platform -l app=vpa-nap-coordinator -o wide

# Verify leader election
kubectl get lease vpa-nap-coordinator -n platform -o yaml
```

### 2. Node Pool Validation
```bash
# Check node pool labels
kubectl get nodes --show-labels | grep node-pool

# Verify pod placement
kubectl get pods --all-namespaces -o wide | grep tenant-
```

### 3. Tenant Policy Testing
```bash
# Create test VPA for each tier
kubectl apply -f - <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: test-dev-vpa
  namespace: tenant-dev-test
  labels:
    tenant-tier: dev
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: test-app
  updatePolicy:
    updateMode: Auto
EOF
```

## Performance Tuning

### Resource Allocation
```yaml
# Coordinator resources by environment
production:
  requests: {cpu: 200m, memory: 256Mi}
  limits: {cpu: 1, memory: 512Mi}
  
staging:
  requests: {cpu: 100m, memory: 128Mi}
  limits: {cpu: 500m, memory: 256Mi}
```

### Scaling Parameters
```yaml
# HPA configuration
hpa:
  minReplicas: 3
  maxReplicas: 5
  targetCPU: 70%
  targetMemory: 80%
  scaleUpPeriod: 300s
  scaleDownPeriod: 300s
```

## Troubleshooting

### Leader Election Issues
```bash
# Check current leader
kubectl get lease vpa-nap-coordinator -n platform -o yaml

# View coordinator logs
kubectl logs -n platform -l app=vpa-nap-coordinator --tail=100

# Force leader re-election
kubectl delete lease vpa-nap-coordinator -n platform
```

### Node Pool Problems
```bash
# Check node taints and labels
kubectl describe node <node-name>

# Verify workload placement
kubectl get pods -o wide | grep "tenant-"

# Check node pool scaling
kubectl get nodes -l node-pool=<pool-name>
```

### Tenant Policy Violations
```bash
# Check Kyverno policy reports
kubectl get polr -A | grep tenant

# View policy violations
kubectl get events --field-selector reason=PolicyViolation

# Check VPA generation
kubectl get vpa --all-namespaces
```

## Dependencies

- Foundation components running
- Kyverno policies active
- Monitoring configured
- Multi-zone cluster setup
- Node pools properly labeled

## Next Steps

After infrastructure deployment:
1. Test failover scenarios
2. Validate tenant tier policies
3. Monitor performance metrics
4. Deploy operational procedures from `05-operations/`
# 02-policies: Kyverno Governance Policies

## Overview

This directory contains Kyverno policies that provide governance, validation, and automation for VPA-NAP integration. These policies prevent conflicts, enforce tenant boundaries, and provide automated resource generation.

## Components

### Core Policies
- **kyverno-vpa-policies.yaml**: Basic VPA-NAP conflict prevention and tenant defaults
- **kyverno-conflict-validation.yaml**: Advanced conflict detection and circuit breaker logic
- **kyverno-mutation-policies.yaml**: Automatic labeling and safety defaults
- **kyverno-generate-policies.yaml**: Automated generation of supporting resources

## Deployment

Deploy policies after foundation components:

```bash
# Prerequisites check
kubectl get pods -n kyverno | grep kyverno

# Deploy all policies
kubectl apply -f 02-policies/

# Verify policies are active
kubectl get clusterpolicies
kubectl get cpol -o wide
```

## Policy Functions

### Conflict Prevention (kyverno-vpa-policies.yaml)
- **VPA-NAP Coordination**: Enforces coordination labels and strategies
- **Resource Limits**: Prevents excessive resource requests that could trigger NAP
- **Update Mode Control**: Restricts VPA update modes based on tenant tier
- **Node Pool Compatibility**: Ensures VPA workloads target compatible node pools

### Advanced Validation (kyverno-conflict-validation.yaml)
- **Oscillation Detection**: Prevents VPA configurations likely to cause resource oscillation
- **Circuit Breaker Logic**: Blocks VPA updates during cluster instability
- **Rate Limiting**: Enforces cooldown periods between VPA updates
- **Tenant Boundary Validation**: Ensures VPA configs respect tenant tier limits

### Automatic Mutation (kyverno-mutation-policies.yaml)
- **Coordination Labels**: Auto-adds required coordination and tier labels
- **Safety Defaults**: Applies conservative defaults for unspecified settings
- **Resource Bounds**: Enforces minimum and maximum resource limits
- **Node Affinity**: Adds appropriate node selectors based on tenant tier

### Resource Generation (kyverno-generate-policies.yaml)
- **Monitoring Configs**: Auto-generates Prometheus rules and dashboards
- **Coordination Resources**: Creates VPANAPCoordination CRDs automatically  
- **Emergency Procedures**: Generates tenant-specific emergency response configs
- **RBAC Resources**: Creates necessary service accounts and role bindings

## Tenant Tier Policies

### Development Tier (tenant-dev-*)
```yaml
# Aggressive optimization allowed
updateMode: "Auto"
maxCPU: "2"
maxMemory: "4Gi"
coordinationStrategy: "coordinated"
```

### Standard Tier (tenant-std-*)
```yaml
# Conservative production settings
updateMode: "Initial" 
maxCPU: "8"
maxMemory: "16Gi"
coordinationStrategy: "isolated"
```

### Premium Tier (tenant-premium-*)
```yaml
# Manual control only
updateMode: "Off"
maxCPU: "32"
maxMemory: "64Gi"
coordinationStrategy: "isolated"
```

## Policy Validation

### Test Policy Syntax
```bash
# Validate policy syntax
kubectl apply --dry-run=client -f 02-policies/

# Test with sample resources
kubectl apply --dry-run=server -f test-vpa-resource.yaml
```

### Monitor Policy Activity
```bash
# Check policy reports
kubectl get cpol -o wide

# View policy violations
kubectl get events --field-selector reason=PolicyViolation

# Check policy performance
kubectl top pods -n kyverno
```

## Circuit Breaker Behavior

The circuit breaker policies automatically:

1. **Monitor Cluster State**: Track node changes and eviction rates
2. **Detect Conflicts**: Identify temporal correlation between VPA and NAP events  
3. **Trigger Protection**: Switch VPAs to "Off" mode when thresholds exceeded
4. **Cooldown Period**: Prevent updates during instability period
5. **Automatic Recovery**: Re-enable coordination when cluster stabilizes

### Thresholds
- **Node Changes**: >5 in 5 minutes triggers circuit breaker
- **Pod Evictions**: >20 in 10 minutes triggers circuit breaker
- **Cooldown Period**: 30 minutes minimum before re-enabling

## Troubleshooting

### Policy Not Working
```bash
# Check Kyverno is running
kubectl get pods -n kyverno

# Check policy status
kubectl describe cpol vpa-nap-conflict-prevention

# View recent policy events
kubectl get events -n kyverno --sort-by='.lastTimestamp'
```

### VPA Creation Blocked
```bash
# Check which policy is blocking
kubectl apply --dry-run=server -f your-vpa.yaml

# Review policy reports
kubectl get polr -A

# Check policy logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno
```

### Resource Not Generated
```bash
# Check generate policies
kubectl get cpol | grep generate

# Verify trigger conditions
kubectl describe deployment your-app

# Check generation events
kubectl get events --field-selector reason=Generated
```

## Policy Tuning

### Adjust Thresholds
Edit policy files to modify:
- Circuit breaker thresholds
- Resource limits by tenant tier
- Cooldown periods
- Rate limiting values

### Disable Specific Policies
```bash
# Disable a policy temporarily
kubectl patch cpol policy-name -p '{"spec":{"validationFailureAction":"audit"}}'

# Re-enable enforcement
kubectl patch cpol policy-name -p '{"spec":{"validationFailureAction":"enforce"}}'
```

## Dependencies

- Kyverno 1.8+ installed and running
- VPA CRDs available
- Foundation components deployed
- Tenant namespaces following naming convention

## Next Steps

After policy deployment:
1. Test with sample VPA resources
2. Deploy monitoring from `03-monitoring/`
3. Verify policy reports and events
4. Tune thresholds based on cluster behavior
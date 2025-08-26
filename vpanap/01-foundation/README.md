# 01-foundation: Core VPA-NAP Components

## Overview

This directory contains the foundational components that must be deployed first. These provide the core VPA-NAP coordination functionality and security hardening required for production use.

## Components

### Core Coordinator
- **vpa-nap-coordinator-alternative.yaml**: Production-ready coordinator using shell scripts and CRDs
- **vpa-nap-coordinator.yaml**: Reference implementation (points to alternative)

### Security & Rate Limiting
- **security-hardening.yaml**: RBAC, network policies, and security controls
- **vpa-rate-limiter.yaml**: Rate limiting for VPA operations

## Deployment Order

Deploy files in this order:

```bash
# 1. Deploy security hardening first
kubectl apply -f security-hardening.yaml

# 2. Deploy core coordinator (production)
kubectl apply -f vpa-nap-coordinator-alternative.yaml

# 3. Deploy rate limiter
kubectl apply -f vpa-rate-limiter.yaml

# 4. Verify deployment
kubectl get pods -n platform -l app=vpa-nap-coordinator
kubectl get vpanapcoordinations --all-namespaces
```

## Verification

After deployment, verify:

1. **Coordinator Health**:
   ```bash
   kubectl get deployment vpa-nap-coordinator-ha -n platform
   kubectl get pods -n platform -l app=vpa-nap-coordinator
   ```

2. **CRD Installation**:
   ```bash
   kubectl get crd vpanapcoordinations.platform.io
   ```

3. **RBAC Configuration**:
   ```bash
   kubectl get clusterrole vpa-nap-coordinator-minimal
   kubectl get clusterrolebinding vpa-nap-coordinator-minimal
   ```

## Key Features

### Coordinator Alternative
- **Leader Election**: HA with leader election using Kubernetes leases
- **Circuit Breaker**: Automatic VPA disabling during conflicts
- **Conflict Detection**: Monitors VPA and NAP events for correlation
- **Custom Resources**: Uses VPANAPCoordination CRD for state management

### Security Hardening
- **Least Privilege RBAC**: Minimal required permissions
- **Network Policies**: Restricted pod-to-pod communication
- **Pod Security Standards**: Restricted security context
- **Emergency Access Controls**: Multi-person authorization required

### Rate Limiting
- **VPA Update Limits**: Prevents excessive VPA modifications
- **Cooldown Periods**: Enforces minimum time between updates
- **Resource Change Limits**: Restricts magnitude of resource changes

## Configuration

### Environment Variables
```yaml
# Coordinator configuration
CIRCUIT_BREAKER_NODE_CHANGES_THRESHOLD: "5"    # Max node changes in 5min
CIRCUIT_BREAKER_EVICTIONS_THRESHOLD: "20"     # Max evictions in 10min
COOLDOWN_MINUTES: "30"                         # Circuit breaker cooldown
CHECK_INTERVAL: "60"                           # Coordination check interval
```

### Custom Resource Example
```yaml
apiVersion: platform.io/v1
kind: VPANAPCoordination
metadata:
  name: my-app-vpa
  namespace: tenant-std-myapp
spec:
  vpaName: "my-app-vpa"
  coordinationStrategy: "coordinated"
  enabled: true
```

## Troubleshooting

### Common Issues

1. **Coordinator Not Starting**:
   ```bash
   kubectl describe pod -n platform -l app=vpa-nap-coordinator
   kubectl logs -n platform -l app=vpa-nap-coordinator
   ```

2. **RBAC Issues**:
   ```bash
   kubectl auth can-i --as=system:serviceaccount:platform:vpa-nap-coordinator-secure get vpa
   ```

3. **CRD Not Found**:
   ```bash
   kubectl get crd | grep vpanapcoordination
   ```

## Dependencies

- Kubernetes 1.23+
- VPA CRDs installed
- Platform namespace created

## Next Steps

After successful deployment:
1. Deploy policies from `02-policies/`
2. Configure monitoring from `03-monitoring/`
3. Deploy infrastructure configs from `04-infrastructure/`
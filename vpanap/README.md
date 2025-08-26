# VPA-NAP Integration for AKS GitOps

## Overview

This directory contains a production-ready Vertical Pod Autoscaler (VPA) and Node Auto Provisioner (NAP) integration designed for multi-tenant AKS clusters. The integration prevents scaling conflicts while maintaining cluster stability and cost efficiency.

## Quick Start

```bash
# Deploy in order:
kubectl apply -f 01-foundation/
kubectl apply -f 02-policies/
kubectl apply -f 03-monitoring/
kubectl apply -f 04-infrastructure/

# Verify deployment
kubectl get pods -n platform -l app=vpa-nap-coordinator
kubectl get clusterpolicies -l component=vpa-nap
```

## Directory Structure

```
vpanap/
├── 01-foundation/          # Core components (deploy first)
├── 02-policies/           # Kyverno policies for governance
├── 03-monitoring/         # Observability and alerting
├── 04-infrastructure/     # HA and infrastructure configs
├── 05-operations/         # Testing and operational procedures
└── docs/                  # Documentation and specifications
```

## Architecture

The VPA-NAP integration provides:

- **Conflict Prevention**: Detects and prevents VPA-NAP scaling conflicts
- **Circuit Breaker**: Automatically disables scaling during instability
- **Multi-Tenant Safety**: Tenant isolation with tier-based policies
- **Observability**: Comprehensive monitoring and alerting
- **High Availability**: Production-ready HA deployment

## Deployment Order

1. **01-foundation**: Core coordinator and security hardening
2. **02-policies**: Kyverno policies for validation and mutation
3. **03-monitoring**: Prometheus rules and ServiceMonitors
4. **04-infrastructure**: HA configurations and tenant policies
5. **05-operations**: Testing framework and operational procedures

## Key Features

### Conflict Prevention
- Temporal correlation detection between VPA and NAP events
- Resource oscillation prevention
- Automated circuit breaker activation

### Multi-Tenant Support
- **Dev Tier**: Aggressive VPA with Auto mode
- **Standard Tier**: Conservative VPA with Initial mode  
- **Premium Tier**: Manual VPA with recommendation-only mode

### Production Ready
- High availability with leader election
- Security hardening with least privilege RBAC
- Comprehensive testing framework
- Operational runbooks and procedures

## Prerequisites

- Kubernetes 1.23+
- Vertical Pod Autoscaler 0.11+
- Kyverno 1.8+
- Prometheus Operator (recommended)

## Configuration

### Tenant Tiers
```yaml
# Dev: Aggressive optimization
tenant-dev-*: updateMode: Auto, maxCPU: 2, maxMemory: 4Gi

# Standard: Balanced approach  
tenant-std-*: updateMode: Initial, maxCPU: 8, maxMemory: 16Gi

# Premium: Manual control
tenant-premium-*: updateMode: Off, maxCPU: 32, maxMemory: 64Gi
```

### Circuit Breaker Thresholds
- Node changes: >5 in 5 minutes
- Pod evictions: >20 in 10 minutes
- Resource oscillation: >30% variance

## Monitoring

Access dashboards and alerts:
- **Overview**: Conflict detection and system health
- **Performance**: Latency and resource usage metrics  
- **Tenant Impact**: Per-tenant resource efficiency

Key metrics:
- `vpa_nap_conflict_score`: Composite conflict risk (0-10)
- `vpa_nap_circuit_breaker_active`: Circuit breaker status
- `vpa_recommendation_accuracy`: Recommendation vs usage

## Troubleshooting

Common issues:
- **Circuit Breaker Active**: Check cluster stability, review recent events
- **VPA Not Updating**: Verify policies, check coordination resource status
- **High Conflict Score**: Review tenant workload patterns, adjust thresholds

See `05-operations/operational-runbooks.md` for detailed procedures.

## Security

- RBAC with least privilege access
- Network policies restricting communication
- Pod security standards compliance
- Multi-person approval for emergency access

## Support

- **Documentation**: See `docs/` directory
- **Runbooks**: See `05-operations/operational-runbooks.md`  
- **Technical Specs**: See `docs/technical-specifications.md`
- **Emergency Procedures**: Contact platform-oncall@company.com
# VPA-NAP Integration for AKS GitOps

## Overview

This directory contains a comprehensive Vertical Pod Autoscaler (VPA) and Node Auto Provisioner (NAP) integration solution designed for multi-tenant AKS clusters. The integration prevents scaling conflicts while maintaining cluster stability and cost efficiency.

**Current Status:** Ready for detailed testing and integration phase

## ⚠️ Important: Pre-Production Testing Required

This solution requires extensive testing and integration validation before production deployment. See the [Testing Strategy](#testing-strategy) section for required validation steps.

## Quick Start (Development/Testing Environment Only)

```bash
# Deploy in TEST environment only:
kubectl apply -f 01-foundation/ --dry-run=server  # Validate first
kubectl apply -f 02-policies/ --dry-run=server
kubectl apply -f 03-monitoring/ --dry-run=server
kubectl apply -f 04-infrastructure/ --dry-run=server

# After validation, deploy to TEST cluster:
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

## Testing Strategy

### Required Testing Phases

Before production deployment, complete these testing phases:

#### Phase 1: Component Testing (2-3 weeks)
- **Unit Tests**: Validate individual components and configurations
- **Integration Tests**: Test component interactions and dependencies
- **Policy Tests**: Verify Kyverno policies work as expected
- **Security Tests**: Validate RBAC, network policies, and hardening

#### Phase 2: System Integration Testing (3-4 weeks)  
- **End-to-End Testing**: Full workflow validation
- **Multi-Tenant Testing**: Validate tenant isolation and tier policies
- **Conflict Simulation**: Test VPA-NAP conflict detection and prevention
- **Performance Testing**: Load testing and resource usage validation

#### Phase 3: Pre-Production Validation (2-3 weeks)
- **Staging Environment**: Deploy in production-like environment
- **Chaos Testing**: Network partitions, node failures, resource exhaustion
- **Disaster Recovery**: Test backup/restore and emergency procedures
- **Operational Readiness**: Validate monitoring, alerting, and runbooks

### Testing Prerequisites

- Kubernetes 1.23+
- Vertical Pod Autoscaler 0.11+
- Kyverno 1.8+
- Prometheus Operator (recommended)
- **Dedicated test clusters** (dev, staging, pre-prod)
- **Test workloads** representing real tenant applications

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
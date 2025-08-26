# 05-operations: Testing and Operational Procedures

## Overview

This directory contains operational procedures, testing frameworks, and deployment strategies for the VPA-NAP integration. These components support day-to-day operations and ensure reliable deployments.

## Components

### Deployment Strategy
- **rollout-plan.yaml**: Phased deployment strategy with validation gates

### Testing Framework
- **testing-framework.yaml**: Comprehensive test suite including unit, integration, and performance tests

### Operations Manual
- **operational-runbooks.md**: Detailed procedures for common operational tasks and troubleshooting

## Testing Framework

### Test Types Available

#### Unit Tests
- **Kyverno Policy Validation**: Syntax and logic verification
- **Coordinator Resource Creation**: CRD and RBAC testing
- **VPA Configuration Validation**: Policy compliance testing
- **Circuit Breaker Logic**: Threshold and trigger testing

#### Integration Tests  
- **VPA-NAP Coordination Flow**: End-to-end workflow testing
- **Multi-Tenant Isolation**: Cross-tenant boundary verification
- **Load Generation and Scaling**: Realistic workload simulation
- **Failure Recovery**: Component failure and recovery testing

#### Performance Tests
- **VPA Response Time**: Recommendation generation latency
- **Coordinator Resource Usage**: Memory and CPU utilization
- **Concurrent Operations**: Multi-VPA operation handling
- **Scalability Limits**: Maximum supported VPA count

#### Chaos Tests
- **Network Partition**: Coordinator isolation scenarios
- **Resource Exhaustion**: High load and resource pressure
- **Component Failures**: Individual service failures

### Running Tests

```bash
# Run all test suites
kubectl apply -f 05-operations/testing-framework.yaml

# Run specific test type
kubectl create job --from=cronjob/vpa-nap-unit-tests unit-test-$(date +%s) -n vpa-nap-testing
kubectl create job --from=cronjob/vpa-nap-integration-tests integration-test-$(date +%s) -n vpa-nap-testing

# Monitor test progress
kubectl get jobs -n vpa-nap-testing
kubectl logs job/unit-test-<id> -n vpa-nap-testing
```

### Test Results
```bash
# View test results
kubectl get configmap test-results-template -n vpa-nap-testing -o yaml

# Check test metrics
kubectl get events -n vpa-nap-testing --field-selector type=Normal
```

## Rollout Strategy

### Deployment Phases

#### Phase 1: Observation (2 weeks)
- Deploy coordinator in observation mode
- Monitor VPA and NAP behavior
- Collect baseline metrics
- No automatic interventions

#### Phase 2: Dev Tier Automation (2 weeks) 
- Enable coordination for dev namespaces
- Test circuit breaker functionality
- Validate tenant isolation
- Monitor for conflicts

#### Phase 3: Standard Tier (4 weeks)
- Gradually enable standard tier tenants
- Implement advanced monitoring
- Test emergency procedures
- Performance optimization

#### Phase 4: Premium Tier (Recommendation Only)
- Premium tenants get recommendations only
- Manual approval for any changes
- Enhanced monitoring and alerting
- Full operational procedures

### Validation Gates

Each phase requires:
- **Health Checks**: All components healthy
- **Performance Metrics**: Within acceptable ranges
- **Security Validation**: No policy violations
- **Tenant Impact**: No service disruption
- **Rollback Testing**: Verified rollback procedures

## Operational Runbooks

The `operational-runbooks.md` file contains detailed procedures for:

### Common Issues
- **VPA-NAP Conflict Detected**: Circuit breaker triggered
- **VPA Recommendations Drifting**: Resource usage misalignment
- **Node Pool Imbalance**: Uneven resource distribution
- **Coordinator Pod Issues**: CrashLooping or performance problems

### Emergency Procedures
- **Level 1**: Immediate VPA disable (<30 seconds)
- **Level 2**: Workload stabilization (<5 minutes)
- **Level 3**: Complete rollback (<15 minutes)

### Maintenance Tasks
- **Daily**: Health checks and conflict monitoring
- **Weekly**: Resource trend analysis and cleanup
- **Monthly**: Threshold tuning and procedure updates

## Deployment Procedures

### Pre-Deployment Checklist
```bash
# 1. Verify prerequisites
kubectl get pods -n kube-system | grep vpa
kubectl get pods -n kyverno

# 2. Run pre-deployment tests
kubectl apply -f 05-operations/testing-framework.yaml
kubectl create job --from=job/vpa-nap-unit-tests pre-deploy-test -n vpa-nap-testing

# 3. Check cluster resources
kubectl top nodes
kubectl get resourcequotas --all-namespaces
```

### Deployment Execution
```bash
# Deploy in sequence with validation
kubectl apply -f 01-foundation/ && sleep 30
kubectl get pods -n platform -l app=vpa-nap-coordinator

kubectl apply -f 02-policies/ && sleep 30  
kubectl get clusterpolicies

kubectl apply -f 03-monitoring/ && sleep 30
kubectl get servicemonitor -n platform

kubectl apply -f 04-infrastructure/ && sleep 30
kubectl get deployment vpa-nap-coordinator-ha -n platform
```

### Post-Deployment Verification
```bash
# Comprehensive health check
./scripts/health-check.sh

# Run smoke tests
kubectl create job --from=cronjob/vpa-nap-integration-tests smoke-test -n vpa-nap-testing

# Verify monitoring
curl http://localhost:8080/metrics  # Port-forward coordinator
```

## Monitoring and Alerting

### Key Operational Metrics
- **System Health**: Coordinator uptime and responsiveness  
- **Conflict Rate**: VPA-NAP conflicts per hour
- **Circuit Breaker**: Trigger frequency and duration
- **Tenant Impact**: Resource efficiency and quota utilization

### Alert Response Procedures
```bash
# Critical alert response (5 minutes)
1. Acknowledge alert in monitoring system
2. Check coordinator health: kubectl get pods -n platform
3. Review recent events: kubectl get events --sort-by='.lastTimestamp'
4. Execute emergency procedure if needed

# Warning alert response (30 minutes)
1. Investigate root cause using runbooks
2. Check performance metrics and trends
3. Apply corrective actions
4. Update monitoring thresholds if needed
```

## Backup and Recovery

### VPA State Backup
**Note**: Using existing cluster backup framework for cluster-level backup. VPA-specific state coordination only.

```bash
# Manual VPA state backup
kubectl get vpa --all-namespaces -o yaml > vpa-state-backup.yaml
kubectl get vpanapcoordinations --all-namespaces -o yaml > coordination-state-backup.yaml

# Restore VPA state
kubectl apply -f vpa-state-backup.yaml
kubectl apply -f coordination-state-backup.yaml
```

## Performance Optimization

### Resource Tuning
```yaml
# Coordinator resource optimization
resources:
  requests: {cpu: 100m, memory: 128Mi}  # Minimal for startup
  limits: {cpu: 500m, memory: 256Mi}    # Allow bursts
```

### Scaling Parameters
```yaml
# HPA tuning for load
targetCPUUtilization: 70%      # Scale before saturation
scaleUpPeriod: 300s           # Gradual scale-up
scaleDownPeriod: 600s         # Conservative scale-down
```

## Troubleshooting

### Common Operational Issues

#### Test Failures
```bash
# Check test pod logs
kubectl logs job/test-job-name -n vpa-nap-testing

# Verify test environment
kubectl get pods -n vpa-nap-testing
kubectl describe pod test-pod-name -n vpa-nap-testing
```

#### Deployment Issues
```bash
# Check deployment status
kubectl rollout status deployment/vpa-nap-coordinator-ha -n platform

# View deployment events
kubectl describe deployment vpa-nap-coordinator-ha -n platform

# Check resource constraints
kubectl describe nodes | grep -A 5 "Allocated resources"
```

## Dependencies

- All previous deployment phases completed
- Testing namespace available
- Monitoring system configured
- Access to operational dashboards
- Emergency contact procedures established

## Success Metrics

### Technical Metrics
- **Availability**: >99.9% coordinator uptime
- **Performance**: <100ms coordination decision time
- **Conflicts**: <1 per day across all tenants
- **Recovery**: <5 minutes emergency response time

### Business Metrics
- **Cost Efficiency**: Improved resource utilization
- **Tenant Satisfaction**: No service disruptions
- **Operational Load**: Reduced manual interventions
- **Stability**: Consistent cluster performance
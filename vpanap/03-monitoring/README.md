# 03-monitoring: Observability and Alerting

## Overview

This directory contains monitoring configurations for the VPA-NAP integration. It provides comprehensive observability through Prometheus metrics, alerting rules, and Grafana dashboards.

## Components

### Core Monitoring
- **monitoring-alerts.yaml**: Basic Prometheus alerting rules and dashboard configs
- **enhanced-monitoring.yaml**: Advanced monitoring with ServiceMonitors and recording rules

## Deployment

Deploy after foundation and policies:

```bash
# Verify Prometheus Operator is available
kubectl get crd servicemonitors.monitoring.coreos.com

# Deploy monitoring configs
kubectl apply -f 03-monitoring/

# Verify ServiceMonitors
kubectl get servicemonitor -n platform
kubectl get prometheusrule -n platform
```

## Monitoring Components

### ServiceMonitors
- **VPA-NAP Coordinator**: Scrapes coordinator metrics on port 8080
- **Custom Metrics**: Additional VPA-specific metrics collection

### Prometheus Rules
- **Critical Alerts**: System-down, conflict storms, circuit breaker issues
- **Performance Alerts**: High CPU/memory, slow response times
- **Tenant Impact Alerts**: Quota violations, oscillating recommendations
- **Operational Alerts**: Backup failures, resource growth

### Recording Rules
- **Conflict Score**: Composite metric (0-10) indicating conflict likelihood
- **Node Efficiency**: Resource utilization considering VPA impact
- **Recommendation Accuracy**: How well VPA predictions match reality
- **Tenant Efficiency**: Per-namespace resource utilization

## Key Metrics

### System Health
```promql
# Coordinator availability
up{job="vpa-nap-coordinator"}

# Circuit breaker status  
vpa_nap_circuit_breaker_active

# Conflict detection score
vpa_nap:conflict_score
```

### Performance Metrics
```promql
# Coordinator resource usage
container_cpu_usage_seconds_total{pod=~"vpa-nap-coordinator.*"}
container_memory_usage_bytes{pod=~"vpa-nap-coordinator.*"}

# VPA recommendation latency
histogram_quantile(0.95, rate(vpa_recommendation_generation_duration_seconds_bucket[5m]))
```

### Business Metrics
```promql
# Resource efficiency
vpa_nap:node_efficiency

# Tenant impact
vpa_nap:tenant_efficiency

# Cost implications
sum(kube_node_info) * 2.5  # Estimated hourly cost
```

## Alerting Rules

### Critical Alerts (Immediate Response)
- **VPANAPCoordinatorDown**: Coordinator pod is not responding
- **VPANAPConflictStorm**: High conflict rate detected (>0.5/min)
- **CircuitBreakerStuck**: Circuit breaker active for >1 hour

### Warning Alerts (Investigation Required)
- **CoordinatorHighCPU**: CPU usage >80% for 5 minutes
- **CoordinatorHighMemory**: Memory usage >80% for 5 minutes  
- **VPARecommendationLatencyHigh**: 95th percentile >15 minutes

### Tenant Alerts (Tenant-Specific)
- **TenantVPAOscillating**: High variance in VPA recommendations
- **TenantResourceQuotaNearLimit**: Approaching quota limits during VPA changes

## Dashboards

### Overview Dashboard
- System health status (coordinator, circuit breaker, conflicts)
- Conflict detection trends and scoring
- Resource efficiency metrics
- Tenant impact heatmap

### Performance Dashboard  
- Coordinator resource usage and performance
- VPA recommendation latency and accuracy
- Node and pod lifecycle events
- API server and etcd impact

### Tenant Dashboard
- Per-tenant resource utilization
- VPA recommendation trends by namespace
- Quota usage and efficiency metrics
- Cost allocation and optimization

## Alert Routing

### Severity-Based Routing
```yaml
critical:
  channels: [slack-critical, email-oncall, pager]
  group_wait: 0s
  repeat_interval: 15m

warning:  
  channels: [slack-ops, email-ops]
  group_wait: 10s
  repeat_interval: 1h
```

### Tenant-Based Routing
```yaml
premium:
  channels: [pager, slack-premium]
  group_wait: 0s

standard:
  channels: [slack-ops, email]
  group_wait: 30s
  
dev:
  channels: [slack-dev]
  group_wait: 5m
```

## Baseline Thresholds

### Normal Operating Ranges
```yaml
coordinator:
  cpu: 100-200m (normal), >400m (warning), >800m (critical)
  memory: 128-256Mi (normal), >256Mi (warning), >512Mi (critical)
  response_time: <100ms (normal), >500ms (warning), >2s (critical)

conflicts:
  rate: 0 (normal), >3/hour (warning), >10/hour (critical)
  
vpa_performance:
  recommendation_latency: <5min (normal), >15min (warning), >30min (critical)
  drift_percentage: <10% (normal), >30% (warning), >100% (critical)
```

## Monitoring Setup

### 1. Verify Prerequisites
```bash
# Check Prometheus Operator
kubectl get pods -n monitoring | grep prometheus-operator

# Check ServiceMonitor CRD
kubectl get crd servicemonitors.monitoring.coreos.com
```

### 2. Deploy Monitoring
```bash
kubectl apply -f 03-monitoring/enhanced-monitoring.yaml
```

### 3. Verify Metrics Collection
```bash
# Check ServiceMonitor targets
kubectl get servicemonitor vpa-nap-coordinator -n platform -o yaml

# Verify metrics endpoint
kubectl port-forward -n platform svc/vpa-nap-coordinator 8080:8080 &
curl http://localhost:8080/metrics
```

### 4. Validate Alerting
```bash
# Check PrometheusRule status
kubectl get prometheusrule -n platform

# View active alerts in Prometheus UI
# Navigate to Alerts tab to see VPA-NAP alerts
```

## Troubleshooting

### Metrics Not Appearing
```bash
# Check ServiceMonitor selector
kubectl get servicemonitor vpa-nap-coordinator -o yaml

# Verify service labels match
kubectl get service vpa-nap-coordinator -o yaml

# Check Prometheus targets
# In Prometheus UI: Status -> Targets
```

### Alerts Not Firing
```bash
# Check PrometheusRule syntax
kubectl describe prometheusrule vpa-nap-enhanced-alerts

# Verify alerting rules loaded
# In Prometheus UI: Status -> Rules

# Check AlertManager config
kubectl get secret alertmanager-config -o yaml
```

### Dashboard Issues
```bash
# Check ConfigMap with grafana_dashboard label
kubectl get configmap vpa-nap-dashboard -o yaml

# Verify Grafana can access ConfigMap
kubectl get pods -n monitoring | grep grafana
```

## Metric Retention

### Recording Rules
- Raw metrics: 1 hour intervals
- Aggregated metrics: 5 minute intervals  
- Long-term trends: 1 day intervals

### Alert History
- Active alerts: Real-time
- Resolved alerts: 7 days
- Alert history: 30 days

## Dependencies

- Prometheus Operator installed
- Grafana for dashboards (recommended)
- AlertManager for notifications
- Foundation and policy components deployed

## Next Steps

After monitoring deployment:
1. Access Grafana dashboards
2. Configure AlertManager notifications
3. Validate alert thresholds match your environment
4. Deploy infrastructure configs from `04-infrastructure/`
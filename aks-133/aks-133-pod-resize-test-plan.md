# AKS 1.33 Dynamic Pod Resizing Test Plan

## Executive Summary
This test plan validates the in-place pod resizing feature introduced in Kubernetes 1.33, ensuring it meets our production requirements for zero-downtime resource adjustments in AKS environments.

## Test Objectives
- Verify dynamic pod resizing functionality without service interruption
- Measure resize latency and performance impact
- Validate proper CPU/memory reallocation and metrics reporting
- Document rollback procedures and known limitations

## Prerequisites
- AKS 1.33 cluster provisioned in staging environment
- Monitoring stack deployed (Prometheus, Grafana)
- kubectl v1.33+ installed
- Azure CLI configured with appropriate permissions

## Test Scenarios

### Scenario 1: Basic Pod Resize Operations
**Objective**: Validate basic resize functionality for CPU and memory

**Test Workload**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resize-test-app
  namespace: resize-testing
spec:
  replicas: 3
  selector:
    matchLabels:
      app: resize-test
  template:
    metadata:
      labels:
        app: resize-test
    spec:
      containers:
      - name: test-app
        image: nginx:latest
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
```

**Test Cases**:
1. CPU Increase: 100m → 200m (requests), 200m → 400m (limits)
2. Memory Increase: 128Mi → 256Mi (requests), 256Mi → 512Mi (limits)
3. CPU Decrease: 200m → 100m (requests)
4. Memory Decrease: 256Mi → 128Mi (requests)
5. Simultaneous CPU and Memory adjustment

### Scenario 2: Load Testing During Resize
**Objective**: Validate resize behavior under active traffic

**Setup**:
- Deploy sample application with HPA enabled
- Generate consistent load using Apache Bench or k6
- Monitor response times and error rates during resize

**Metrics to Capture**:
- Request latency (p50, p95, p99)
- Error rate percentage
- Pod restart count
- Time to complete resize operation

### Scenario 3: Resource-Intensive Application Resize
**Objective**: Test resize with memory-intensive workloads (e.g., JVM applications)

**Test Workload**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: java-resize-test
  namespace: resize-testing
spec:
  replicas: 2
  selector:
    matchLabels:
      app: java-test
  template:
    metadata:
      labels:
        app: java-test
    spec:
      containers:
      - name: java-app
        image: openjdk:11-jre-slim
        command: ["java", "-Xmx256m", "-jar", "/app/sample.jar"]
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
```

**Test Focus**:
- JVM heap behavior during memory resize
- Application stability during memory shrinkage
- GC impact and performance

### Scenario 4: Edge Cases and Failure Scenarios
**Objective**: Identify and document failure modes

**Test Cases**:
1. Resize beyond node capacity
2. Resize with insufficient cluster resources
3. Rapid successive resize operations
4. Resize during pod eviction
5. Resize with PodDisruptionBudget constraints

## Test Execution Steps

### Pre-Test Setup
```bash
# Create test namespace
kubectl create namespace resize-testing

# Label nodes for testing
kubectl label nodes <node-name> test-type=resize-validation

# Deploy monitoring stack
kubectl apply -f monitoring-stack.yaml

# Record initial cluster state
kubectl get nodes -o wide > pre-test-nodes.txt
kubectl top nodes > pre-test-resources.txt
```

### Test Execution

#### Step 1: Deploy Test Workload
```bash
kubectl apply -f test-workload.yaml
kubectl wait --for=condition=ready pod -l app=resize-test -n resize-testing --timeout=60s
```

#### Step 2: Baseline Performance Measurement
```bash
# Record baseline metrics
kubectl top pods -n resize-testing > baseline-metrics.txt

# Generate load for baseline
kubectl run -it --rm load-generator --image=busybox /bin/sh
# Inside pod: while true; do wget -q -O- http://resize-test-app; done
```

#### Step 3: Execute Resize Operations
```bash
# Method 1: kubectl patch
kubectl patch deployment resize-test-app -n resize-testing --patch '
spec:
  template:
    spec:
      containers:
      - name: test-app
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "400m"
            memory: "512Mi"'

# Method 2: kubectl edit
kubectl edit deployment resize-test-app -n resize-testing

# Monitor resize status
watch kubectl get pods -n resize-testing -o wide
```

#### Step 4: Validation and Metrics Collection
```bash
# Check pod conditions
kubectl describe pod <pod-name> -n resize-testing | grep -A5 "Conditions:"

# Verify resource allocation
kubectl get pod <pod-name> -n resize-testing -o jsonpath='{.spec.containers[0].resources}'

# Collect metrics
kubectl top pods -n resize-testing > post-resize-metrics.txt

# Check for restarts
kubectl get pods -n resize-testing -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount

# Verify application health
kubectl logs <pod-name> -n resize-testing --tail=50
```

### Post-Test Analysis
```bash
# Generate resize timeline
kubectl get events -n resize-testing --sort-by='.lastTimestamp' | grep -i resize

# Export Prometheus metrics
curl -G http://prometheus:9090/api/v1/query_range \
  --data-urlencode 'query=container_memory_usage_bytes{namespace="resize-testing"}' \
  --data-urlencode 'start=<start-time>' \
  --data-urlencode 'end=<end-time>' \
  --data-urlencode 'step=15s' > memory-usage.json

# Cleanup
kubectl delete namespace resize-testing
```

## Success Criteria
- [ ] Pods resize without restart (restart count = 0)
- [ ] Resize completes within 30 seconds
- [ ] No service interruption (0% error rate during resize)
- [ ] Resource metrics accurately reflect new allocations
- [ ] Application logs show no errors related to resize
- [ ] Readiness/liveness probes continue passing

## Known Limitations (from Research)
- Linux-only support (Windows nodes not supported)
- Only CPU and memory can be resized
- Cannot remove existing resource requests
- Not compatible with init containers or ephemeral containers
- JVM applications may not fully utilize increased memory without restart
- Static CPU/memory management pods cannot be resized

## Rollback Procedures
If resize causes issues:
1. Revert deployment to previous resource specifications
2. Force pod recreation if resize is stuck: `kubectl delete pod <pod-name> -n resize-testing`
3. Scale deployment to 0 and back: `kubectl scale deployment resize-test-app --replicas=0`
4. Document issue and open support ticket with Azure

## Test Results Documentation Template
```markdown
Test Date: [DATE]
AKS Version: 1.33.x
Test Environment: [Staging/Dev]

### Test Summary
- Total Test Cases: X
- Passed: X
- Failed: X
- Blocked: X

### Key Findings
1. [Finding 1]
2. [Finding 2]

### Performance Metrics
- Average Resize Time: Xs
- Pod Restart Count: X
- Service Availability: X%

### Recommendations
- [Recommendation 1]
- [Recommendation 2]

### Sign-off
- DevOps Lead: [Name]
- Platform Team: [Name]
```

## References
- [Kubernetes 1.33 Release Notes](https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/)
- [AKS Security Bulletins](https://docs.azure.cn/en-us/aks/security-bulletins/overview)
- [LinkedIn: Kubernetes 1.33 Pod Resizing](https://www.linkedin.com/pulse/kubernetes-133-resizing-pods-gopal-das-tsxff)
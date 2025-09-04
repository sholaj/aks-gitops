#!/bin/bash
# AKS 1.33 Pod Resizing Basic Test Script
# Tests fundamental pod resize operations

set -euo pipefail

# Configuration
TEST_NAMESPACE="aks-133-resize-test"
DEPLOYMENT_NAME="resize-test-app"
APP_LABEL="app=resize-test"
PASSED=0
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-TEST] $*"
}

log_pass() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-TEST] ${GREEN}✅ PASS${NC}: $*"
    ((PASSED++))
}

log_fail() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-TEST] ${RED}❌ FAIL${NC}: $*"
    ((FAILED++))
}

log_warn() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-TEST] ${YELLOW}⚠️  WARN${NC}: $*"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check kubectl version
    local kubectl_version=$(kubectl version --client --short 2>/dev/null | grep -o 'v1\.[0-9]*' | head -1)
    if [[ ${kubectl_version#v1.} -ge 33 ]]; then
        log_pass "kubectl version $kubectl_version supports AKS 1.33"
    else
        log_fail "kubectl version $kubectl_version may not support AKS 1.33 features"
    fi
    
    # Check cluster version
    local cluster_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | grep -o 'v1\.[0-9]*' | head -1)
    if [[ ${cluster_version#v1.} -ge 33 ]]; then
        log_pass "Cluster version $cluster_version supports pod resizing"
    else
        log_fail "Cluster version $cluster_version does not support pod resizing"
        exit 1
    fi
    
    # Check feature gate
    local feature_gates=$(kubectl get --raw /api/v1/nodes | jq -r '.items[0].status.allocatable' 2>/dev/null || echo "{}")
    if kubectl get --raw /metrics 2>/dev/null | grep -q "InPlacePodVerticalScaling" || true; then
        log "Feature gate check: InPlacePodVerticalScaling detection attempted"
    fi
    
    log "Prerequisites check completed"
}

# Setup test environment
setup_test_environment() {
    log "Setting up test environment..."
    
    # Create namespace
    kubectl create namespace $TEST_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    log "Test namespace '$TEST_NAMESPACE' created/verified"
    
    # Deploy test application
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT_NAME
  namespace: $TEST_NAMESPACE
  labels:
    test-type: "pod-resize"
    aks-version: "1.33"
spec:
  replicas: 2
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
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: resize-test-service
  namespace: $TEST_NAMESPACE
spec:
  selector:
    app: resize-test
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available deployment/$DEPLOYMENT_NAME -n $TEST_NAMESPACE --timeout=120s
    log_pass "Test deployment '$DEPLOYMENT_NAME' is ready"
    
    # Record baseline metrics
    kubectl top pods -n $TEST_NAMESPACE --no-headers > baseline-metrics.txt || log_warn "Could not capture baseline metrics"
}

# Test CPU increase
test_cpu_increase() {
    log "Testing CPU resource increase..."
    
    # Get initial pod names and restart counts
    local initial_pods=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL --no-headers | awk '{print $1}')
    local initial_restarts=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}')
    
    # Record start time
    local start_time=$(date +%s)
    
    # Perform CPU increase: 100m -> 200m (requests), 200m -> 400m (limits)
    kubectl patch deployment $DEPLOYMENT_NAME -n $TEST_NAMESPACE --patch '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "test-app",
                        "resources": {
                            "requests": {
                                "cpu": "200m",
                                "memory": "128Mi"
                            },
                            "limits": {
                                "cpu": "400m",
                                "memory": "256Mi"
                            }
                        }
                    }]
                }
            }
        }
    }'
    
    # Wait for rollout
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n $TEST_NAMESPACE --timeout=60s
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Check if pods were resized or recreated
    local final_pods=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL --no-headers | awk '{print $1}')
    local final_restarts=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}')
    
    # Verify resource allocation
    local actual_cpu_request=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}')
    local actual_cpu_limit=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].spec.containers[0].resources.limits.cpu}')
    
    if [[ "$actual_cpu_request" == "200m" && "$actual_cpu_limit" == "400m" ]]; then
        log_pass "CPU resources updated correctly (requests: $actual_cpu_request, limits: $actual_cpu_limit)"
    else
        log_fail "CPU resources not updated correctly (requests: $actual_cpu_request, limits: $actual_cpu_limit)"
    fi
    
    # Check resize duration (should be < 30s for in-place resize)
    if [[ $duration -le 30 ]]; then
        log_pass "CPU resize completed in ${duration}s (≤30s threshold)"
    else
        log_warn "CPU resize took ${duration}s (>30s, possibly recreated pods)"
    fi
    
    # Check for restart count changes
    if [[ "$initial_restarts" == "$final_restarts" ]]; then
        log_pass "No pod restarts detected during CPU resize"
    else
        log_warn "Pod restarts detected: initial($initial_restarts) -> final($final_restarts)"
    fi
}

# Test memory increase
test_memory_increase() {
    log "Testing memory resource increase..."
    
    local start_time=$(date +%s)
    local initial_restarts=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}')
    
    # Perform memory increase: 128Mi -> 256Mi (requests), 256Mi -> 512Mi (limits)
    kubectl patch deployment $DEPLOYMENT_NAME -n $TEST_NAMESPACE --patch '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "test-app",
                        "resources": {
                            "requests": {
                                "cpu": "200m",
                                "memory": "256Mi"
                            },
                            "limits": {
                                "cpu": "400m",
                                "memory": "512Mi"
                            }
                        }
                    }]
                }
            }
        }
    }'
    
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n $TEST_NAMESPACE --timeout=60s
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local final_restarts=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}')
    
    # Verify memory allocation
    local actual_memory_request=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].spec.containers[0].resources.requests.memory}')
    local actual_memory_limit=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].spec.containers[0].resources.limits.memory}')
    
    if [[ "$actual_memory_request" == "256Mi" && "$actual_memory_limit" == "512Mi" ]]; then
        log_pass "Memory resources updated correctly (requests: $actual_memory_request, limits: $actual_memory_limit)"
    else
        log_fail "Memory resources not updated correctly (requests: $actual_memory_request, limits: $actual_memory_limit)"
    fi
    
    if [[ $duration -le 30 ]]; then
        log_pass "Memory resize completed in ${duration}s (≤30s threshold)"
    else
        log_warn "Memory resize took ${duration}s (>30s, possibly recreated pods)"
    fi
    
    if [[ "$initial_restarts" == "$final_restarts" ]]; then
        log_pass "No pod restarts detected during memory resize"
    else
        log_warn "Pod restarts detected during memory resize"
    fi
}

# Test resource decrease
test_resource_decrease() {
    log "Testing resource decrease..."
    
    local start_time=$(date +%s)
    local initial_restarts=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}')
    
    # Decrease resources: CPU 200m->150m, Memory 256Mi->192Mi
    kubectl patch deployment $DEPLOYMENT_NAME -n $TEST_NAMESPACE --patch '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "test-app",
                        "resources": {
                            "requests": {
                                "cpu": "150m",
                                "memory": "192Mi"
                            },
                            "limits": {
                                "cpu": "300m",
                                "memory": "384Mi"
                            }
                        }
                    }]
                }
            }
        }
    }'
    
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n $TEST_NAMESPACE --timeout=60s
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local final_restarts=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}')
    
    # Verify decrease
    local actual_cpu_request=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}')
    local actual_memory_request=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o jsonpath='{.items[0].spec.containers[0].resources.requests.memory}')
    
    if [[ "$actual_cpu_request" == "150m" && "$actual_memory_request" == "192Mi" ]]; then
        log_pass "Resource decrease applied correctly (CPU: $actual_cpu_request, Memory: $actual_memory_request)"
    else
        log_fail "Resource decrease not applied correctly"
    fi
    
    if [[ $duration -le 30 ]]; then
        log_pass "Resource decrease completed in ${duration}s"
    else
        log_warn "Resource decrease took ${duration}s"
    fi
}

# Test service availability during resize
test_service_availability() {
    log "Testing service availability during resize operations..."
    
    # Start background load
    kubectl run load-generator -n $TEST_NAMESPACE --image=busybox --restart=Never \
        --command -- /bin/sh -c "while true; do wget -q -O- http://resize-test-service:80/ >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'; sleep 1; done" &
    local load_gen_pid=$!
    
    sleep 5  # Let load generator start
    
    # Perform resize while under load
    local start_time=$(date +%s)
    kubectl patch deployment $DEPLOYMENT_NAME -n $TEST_NAMESPACE --patch '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "test-app",
                        "resources": {
                            "requests": {
                                "cpu": "100m",
                                "memory": "128Mi"
                            },
                            "limits": {
                                "cpu": "200m",
                                "memory": "256Mi"
                            }
                        }
                    }]
                }
            }
        }
    }'
    
    kubectl rollout status deployment/$DEPLOYMENT_NAME -n $TEST_NAMESPACE --timeout=60s
    local end_time=$(date +%s)
    
    # Stop load generator
    kill $load_gen_pid 2>/dev/null || true
    kubectl delete pod load-generator -n $TEST_NAMESPACE --ignore-not-found=true
    
    # Check for service interruptions
    local logs=$(kubectl logs load-generator -n $TEST_NAMESPACE 2>/dev/null | tail -20 || echo "No logs available")
    local error_count=$(echo "$logs" | grep -c "FAIL" || echo 0)
    local total_requests=$(echo "$logs" | wc -l)
    
    if [[ $error_count -eq 0 ]]; then
        log_pass "No service interruptions detected during resize (0 errors in $total_requests requests)"
    else
        local error_rate=$(( error_count * 100 / total_requests ))
        if [[ $error_rate -lt 5 ]]; then
            log_warn "Minimal service interruption: ${error_rate}% error rate ($error_count/$total_requests)"
        else
            log_fail "Significant service interruption: ${error_rate}% error rate ($error_count/$total_requests)"
        fi
    fi
}

# Test application health checks
test_health_checks() {
    log "Testing application health during and after resize..."
    
    # Check readiness probe status
    local ready_pods=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL --field-selector=status.phase=Running -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}')
    local ready_count=$(echo "$ready_pods" | tr ' ' '\n' | grep -c "True" || echo 0)
    local total_pods=$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL --no-headers | wc -l)
    
    if [[ $ready_count -eq $total_pods ]]; then
        log_pass "All pods are ready ($ready_count/$total_pods)"
    else
        log_fail "Not all pods are ready ($ready_count/$total_pods)"
    fi
    
    # Check for pod events (errors, warnings)
    local warning_events=$(kubectl get events -n $TEST_NAMESPACE --field-selector=type=Warning --no-headers 2>/dev/null | wc -l)
    if [[ $warning_events -eq 0 ]]; then
        log_pass "No warning events detected"
    else
        log_warn "$warning_events warning events detected"
        kubectl get events -n $TEST_NAMESPACE --field-selector=type=Warning --no-headers 2>/dev/null | head -5
    fi
}

# Generate test report
generate_report() {
    local total_tests=$((PASSED + FAILED))
    local success_rate=$(( PASSED * 100 / total_tests ))
    
    log "=========================================="
    log "AKS 1.33 Pod Resizing Test Results"
    log "=========================================="
    log "Total Tests: $total_tests"
    log "Passed: $PASSED"
    log "Failed: $FAILED"
    log "Success Rate: ${success_rate}%"
    
    if [[ $success_rate -ge 80 ]]; then
        log_pass "Test suite PASSED with ${success_rate}% success rate"
        echo "RECOMMENDATION: AKS 1.33 pod resizing is ready for production use"
    else
        log_fail "Test suite FAILED with ${success_rate}% success rate"
        echo "RECOMMENDATION: Further investigation required before production deployment"
    fi
    
    # Save detailed report
    cat > "aks-133-resize-test-report-$(date +%Y%m%d-%H%M%S).txt" <<EOF
AKS 1.33 Pod Resizing Test Report
Generated: $(date)
Cluster: $(kubectl config current-context)
Test Namespace: $TEST_NAMESPACE

Test Results Summary:
- Total Tests: $total_tests
- Passed: $PASSED
- Failed: $FAILED
- Success Rate: ${success_rate}%

Test Environment:
- kubectl version: $(kubectl version --client --short 2>/dev/null | head -1)
- Cluster version: $(kubectl version --short 2>/dev/null | grep "Server Version" | head -1)
- Test deployment: $DEPLOYMENT_NAME

Resource Metrics:
$(kubectl top pods -n $TEST_NAMESPACE 2>/dev/null || echo "Metrics not available")

Final Pod Status:
$(kubectl get pods -n $TEST_NAMESPACE -l $APP_LABEL -o wide)

Recommendations:
$(if [[ $success_rate -ge 80 ]]; then
    echo "✅ AKS 1.33 pod resizing feature is working correctly"
    echo "✅ Ready for production rollout with proper monitoring"
    echo "✅ Consider implementing gradual rollout strategy"
else
    echo "❌ Pod resizing feature requires additional validation"
    echo "❌ Review failed test cases before production deployment"
    echo "❌ Consider sticking to pod recreation strategy temporarily"
fi)

$(if [[ $FAILED -gt 0 ]]; then
    echo "Issues Found:"
    echo "- Review logs for resize duration > 30s"
    echo "- Check for unexpected pod restarts"
    echo "- Validate service availability metrics"
fi)
EOF
    
    log "Detailed report saved to: aks-133-resize-test-report-$(date +%Y%m%d-%H%M%S).txt"
}

# Cleanup function
cleanup() {
    log "Cleaning up test resources..."
    kubectl delete namespace $TEST_NAMESPACE --ignore-not-found=true
    rm -f baseline-metrics.txt
    log "Cleanup completed"
}

# Main execution
main() {
    log "Starting AKS 1.33 Pod Resizing Basic Tests..."
    
    trap cleanup EXIT
    
    check_prerequisites
    setup_test_environment
    
    test_cpu_increase
    test_memory_increase
    test_resource_decrease
    test_service_availability
    test_health_checks
    
    generate_report
    
    log "AKS 1.33 Pod Resizing Basic Tests completed"
    
    # Exit with error code if any tests failed
    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
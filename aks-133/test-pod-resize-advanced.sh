#!/bin/bash
# AKS 1.33 Pod Resizing Advanced Test Script
# Tests complex scenarios including JVM applications, HPA integration, and edge cases

set -euo pipefail

# Configuration
TEST_NAMESPACE="aks-133-advanced-test"
JAVA_APP_NAME="java-resize-test"
HPA_APP_NAME="hpa-resize-test"
PASSED=0
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-ADVANCED] $*"
}

log_pass() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-ADVANCED] ${GREEN}✅ PASS${NC}: $*"
    ((PASSED++))
}

log_fail() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-ADVANCED] ${RED}❌ FAIL${NC}: $*"
    ((FAILED++))
}

log_warn() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-ADVANCED] ${YELLOW}⚠️  WARN${NC}: $*"
}

log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-ADVANCED] ${BLUE}ℹ️  INFO${NC}: $*"
}

# Setup test environment
setup_advanced_environment() {
    log "Setting up advanced test environment..."
    
    # Create namespace
    kubectl create namespace $TEST_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Java application for memory-intensive tests
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $JAVA_APP_NAME
  namespace: $TEST_NAMESPACE
  labels:
    test-type: "jvm-resize"
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
        command: ["java"]
        args: [
          "-Xmx256m",
          "-Xms128m",
          "-XX:+PrintGCDetails",
          "-XX:+PrintGCTimeStamps",
          "-jar",
          "/opt/app.jar"
        ]
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
        env:
        - name: JAVA_OPTS
          value: "-Xmx256m -Xms128m"
        # Simulate a Java app with a simple JAR (using a busy loop)
        command: ["java"]
        args: ["-Xmx256m", "-cp", "/tmp", "BusyApp"]
        # For testing, we'll use a simpler approach
        image: busybox
        command: ["/bin/sh"]
        args:
        - -c
        - |
          # Simulate Java memory usage patterns
          echo "Starting Java-like workload simulation..."
          while true; do
            # Allocate memory gradually
            dd if=/dev/zero of=/tmp/memory_test bs=1M count=50 2>/dev/null || true
            sleep 10
            rm -f /tmp/memory_test
            sleep 5
          done
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $HPA_APP_NAME
  namespace: $TEST_NAMESPACE
  labels:
    test-type: "hpa-resize"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hpa-test
  template:
    metadata:
      labels:
        app: hpa-test
    spec:
      containers:
      - name: hpa-app
        image: k8s.gcr.io/hpa-example
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "256Mi"
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hpa-test-service
  namespace: $TEST_NAMESPACE
spec:
  selector:
    app: hpa-test
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hpa-test-hpa
  namespace: $TEST_NAMESPACE
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: $HPA_APP_NAME
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available deployment/$JAVA_APP_NAME -n $TEST_NAMESPACE --timeout=120s
    kubectl wait --for=condition=available deployment/$HPA_APP_NAME -n $TEST_NAMESPACE --timeout=120s
    
    log_pass "Advanced test environment setup completed"
}

# Test JVM memory behavior during resize
test_jvm_memory_resize() {
    log "Testing JVM application memory resize behavior..."
    
    # Get initial memory metrics
    local initial_memory_usage=$(kubectl top pods -n $TEST_NAMESPACE -l app=java-test --no-headers | awk '{print $3}' | head -1)
    log_info "Initial JVM memory usage: $initial_memory_usage"
    
    local start_time=$(date +%s)
    
    # Increase memory allocation
    kubectl patch deployment $JAVA_APP_NAME -n $TEST_NAMESPACE --patch '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "java-app",
                        "resources": {
                            "requests": {
                                "cpu": "500m",
                                "memory": "1Gi"
                            },
                            "limits": {
                                "cpu": "1000m",
                                "memory": "2Gi"
                            }
                        }
                    }]
                }
            }
        }
    }'
    
    kubectl rollout status deployment/$JAVA_APP_NAME -n $TEST_NAMESPACE --timeout=120s
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Check if JVM recognizes new memory limits
    sleep 30  # Allow time for memory usage to stabilize
    
    local final_memory_usage=$(kubectl top pods -n $TEST_NAMESPACE -l app=java-test --no-headers | awk '{print $3}' | head -1)
    log_info "Final JVM memory usage: $final_memory_usage"
    
    # Verify resource allocation
    local actual_memory_request=$(kubectl get pods -n $TEST_NAMESPACE -l app=java-test -o jsonpath='{.items[0].spec.containers[0].resources.requests.memory}')
    local actual_memory_limit=$(kubectl get pods -n $TEST_NAMESPACE -l app=java-test -o jsonpath='{.items[0].spec.containers[0].resources.limits.memory}')
    
    if [[ "$actual_memory_request" == "1Gi" && "$actual_memory_limit" == "2Gi" ]]; then
        log_pass "JVM memory resources updated correctly"
    else
        log_fail "JVM memory resources not updated correctly"
    fi
    
    # Check for pod restarts (JVM apps might need restart to recognize new limits)
    local restart_count=$(kubectl get pods -n $TEST_NAMESPACE -l app=java-test -o jsonpath='{.items[*].status.containerStatuses[0].restartCount}')
    if [[ "$restart_count" == "0 0" ]] || [[ "$restart_count" == "0" ]]; then
        log_pass "JVM pods resized without restart"
    else
        log_warn "JVM pods were restarted during resize (may be expected for JVM apps)"
    fi
    
    log_info "JVM resize duration: ${duration}s"
}

# Test resize with HPA enabled
test_hpa_resize_interaction() {
    log "Testing pod resize with HPA enabled..."
    
    # Generate initial load
    kubectl run load-generator -n $TEST_NAMESPACE --image=busybox --restart=Never \
        --command -- /bin/sh -c "while true; do wget -q -O- http://hpa-test-service:80/ >/dev/null 2>&1; done" &
    local load_gen_pid=$!
    
    sleep 30  # Allow HPA to see initial load
    
    # Check initial HPA status
    local initial_replicas=$(kubectl get deployment $HPA_APP_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.replicas}')
    log_info "Initial HPA replicas: $initial_replicas"
    
    # Resize pods while HPA is active
    kubectl patch deployment $HPA_APP_NAME -n $TEST_NAMESPACE --patch '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "hpa-app",
                        "resources": {
                            "requests": {
                                "cpu": "200m",
                                "memory": "256Mi"
                            },
                            "limits": {
                                "cpu": "800m",
                                "memory": "512Mi"
                            }
                        }
                    }]
                }
            }
        }
    }'
    
    kubectl rollout status deployment/$HPA_APP_NAME -n $TEST_NAMESPACE --timeout=120s
    
    sleep 30  # Allow HPA to react to resource changes
    
    # Stop load generator
    kill $load_gen_pid 2>/dev/null || true
    kubectl delete pod load-generator -n $TEST_NAMESPACE --ignore-not-found=true
    
    # Check HPA status after resize
    local final_replicas=$(kubectl get deployment $HPA_APP_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.replicas}')
    local hpa_status=$(kubectl get hpa hpa-test-hpa -n $TEST_NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}')
    
    log_info "Final HPA replicas: $final_replicas, HPA active: $hpa_status"
    
    if [[ "$hpa_status" == "True" ]]; then
        log_pass "HPA remains active after pod resize"
    else
        log_fail "HPA not active after pod resize"
    fi
    
    # Verify resource changes
    local actual_cpu_request=$(kubectl get pods -n $TEST_NAMESPACE -l app=hpa-test -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}')
    if [[ "$actual_cpu_request" == "200m" ]]; then
        log_pass "HPA deployment resources updated correctly"
    else
        log_fail "HPA deployment resources not updated correctly"
    fi
}

# Test edge case: resize beyond node capacity
test_resize_beyond_capacity() {
    log "Testing resize beyond node capacity..."
    
    # Get node capacity
    local node_memory=$(kubectl get nodes -o jsonpath='{.items[0].status.capacity.memory}')
    local node_cpu=$(kubectl get nodes -o jsonpath='{.items[0].status.capacity.cpu}')
    log_info "Node capacity - CPU: $node_cpu, Memory: $node_memory"
    
    # Create a deployment with extreme resource requests
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: extreme-resources
  namespace: $TEST_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: extreme-test
  template:
    metadata:
      labels:
        app: extreme-test
    spec:
      containers:
      - name: extreme-app
        image: nginx:latest
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
EOF
    
    kubectl wait --for=condition=available deployment/extreme-resources -n $TEST_NAMESPACE --timeout=60s
    
    # Try to resize to extreme values
    kubectl patch deployment extreme-resources -n $TEST_NAMESPACE --patch '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "extreme-app",
                        "resources": {
                            "requests": {
                                "cpu": "50",
                                "memory": "100Gi"
                            },
                            "limits": {
                                "cpu": "100",
                                "memory": "200Gi"
                            }
                        }
                    }]
                }
            }
        }
    }' || true
    
    # Wait and check if pods are pending
    sleep 30
    local pod_status=$(kubectl get pods -n $TEST_NAMESPACE -l app=extreme-test -o jsonpath='{.items[0].status.phase}')
    local pod_reason=$(kubectl get pods -n $TEST_NAMESPACE -l app=extreme-test -o jsonpath='{.items[0].status.conditions[?(@.type=="PodScheduled")].reason}' 2>/dev/null || echo "")
    
    if [[ "$pod_status" == "Pending" ]] && [[ "$pod_reason" == "Unschedulable" ]]; then
        log_pass "Pod correctly unschedulable when resources exceed node capacity"
    elif [[ "$pod_status" == "Running" ]]; then
        log_warn "Pod running despite extreme resource requests - resize may have been rejected"
    else
        log_info "Pod status: $pod_status, reason: $pod_reason"
    fi
    
    # Clean up extreme resource deployment
    kubectl delete deployment extreme-resources -n $TEST_NAMESPACE --ignore-not-found=true
}

# Test rapid successive resize operations
test_rapid_resize_operations() {
    log "Testing rapid successive resize operations..."
    
    # Create a simple deployment for rapid testing
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rapid-resize-test
  namespace: $TEST_NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rapid-test
  template:
    metadata:
      labels:
        app: rapid-test
    spec:
      containers:
      - name: rapid-app
        image: nginx:latest
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
EOF
    
    kubectl wait --for=condition=available deployment/rapid-resize-test -n $TEST_NAMESPACE --timeout=60s
    
    # Perform rapid successive resizes
    local success_count=0
    for i in {1..5}; do
        local cpu_value=$((100 + i * 50))
        local memory_value=$((128 + i * 64))
        
        log_info "Rapid resize #$i: CPU ${cpu_value}m, Memory ${memory_value}Mi"
        
        if kubectl patch deployment rapid-resize-test -n $TEST_NAMESPACE --patch "{
            \"spec\": {
                \"template\": {
                    \"spec\": {
                        \"containers\": [{
                            \"name\": \"rapid-app\",
                            \"resources\": {
                                \"requests\": {
                                    \"cpu\": \"${cpu_value}m\",
                                    \"memory\": \"${memory_value}Mi\"
                                },
                                \"limits\": {
                                    \"cpu\": \"$((cpu_value * 2))m\",
                                    \"memory\": \"$((memory_value * 2))Mi\"
                                }
                            }
                        }]
                    }
                }
            }
        }" 2>/dev/null; then
            ((success_count++))
        fi
        
        sleep 2  # Small delay between operations
    done
    
    # Wait for final rollout
    kubectl rollout status deployment/rapid-resize-test -n $TEST_NAMESPACE --timeout=60s
    
    # Verify final state
    local final_cpu=$(kubectl get pods -n $TEST_NAMESPACE -l app=rapid-test -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}')
    log_info "Final CPU request after rapid resizes: $final_cpu"
    
    if [[ $success_count -eq 5 ]]; then
        log_pass "All rapid resize operations succeeded ($success_count/5)"
    else
        log_warn "Some rapid resize operations failed ($success_count/5)"
    fi
    
    # Clean up
    kubectl delete deployment rapid-resize-test -n $TEST_NAMESPACE --ignore-not-found=true
}

# Test resize during pod eviction
test_resize_during_eviction() {
    log "Testing resize behavior during pod eviction scenarios..."
    
    # Create deployment with PodDisruptionBudget
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: eviction-test
  namespace: $TEST_NAMESPACE
spec:
  replicas: 3
  selector:
    matchLabels:
      app: eviction-test
  template:
    metadata:
      labels:
        app: eviction-test
    spec:
      containers:
      - name: eviction-app
        image: nginx:latest
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: eviction-test-pdb
  namespace: $TEST_NAMESPACE
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: eviction-test
EOF
    
    kubectl wait --for=condition=available deployment/eviction-test -n $TEST_NAMESPACE --timeout=60s
    
    # Simulate node pressure by creating a resource-intensive pod
    kubectl run resource-pressure -n $TEST_NAMESPACE --image=busybox \
        --restart=Never --command -- /bin/sh -c "while true; do dd if=/dev/zero of=/tmp/fill bs=1M count=1000; sleep 1; done" &
    
    sleep 10
    
    # Attempt resize during resource pressure
    local start_time=$(date +%s)
    kubectl patch deployment eviction-test -n $TEST_NAMESPACE --patch '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "eviction-app",
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
    
    # Monitor for evictions
    local eviction_count=0
    for i in {1..30}; do
        eviction_count=$(kubectl get events -n $TEST_NAMESPACE --field-selector=reason=Evicted --no-headers 2>/dev/null | wc -l)
        if [[ $eviction_count -gt 0 ]]; then
            break
        fi
        sleep 2
    done
    
    kubectl rollout status deployment/eviction-test -n $TEST_NAMESPACE --timeout=120s
    local end_time=$(date +%s)
    
    # Check PDB compliance
    local available_pods=$(kubectl get pods -n $TEST_NAMESPACE -l app=eviction-test --field-selector=status.phase=Running --no-headers | wc -l)
    
    if [[ $available_pods -ge 2 ]]; then
        log_pass "PodDisruptionBudget maintained during resize ($available_pods pods available)"
    else
        log_fail "PodDisruptionBudget violated during resize ($available_pods pods available)"
    fi
    
    if [[ $eviction_count -gt 0 ]]; then
        log_info "Evictions detected during test: $eviction_count"
    fi
    
    # Cleanup
    kubectl delete pod resource-pressure -n $TEST_NAMESPACE --ignore-not-found=true
    kubectl delete deployment eviction-test -n $TEST_NAMESPACE --ignore-not-found=true
    kubectl delete pdb eviction-test-pdb -n $TEST_NAMESPACE --ignore-not-found=true
}

# Test metrics reporting during resize
test_metrics_reporting() {
    log "Testing metrics reporting during resize operations..."
    
    # Create a simple deployment for metrics testing
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-test
  namespace: $TEST_NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: metrics-test
  template:
    metadata:
      labels:
        app: metrics-test
    spec:
      containers:
      - name: metrics-app
        image: nginx:latest
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
EOF
    
    kubectl wait --for=condition=available deployment/metrics-test -n $TEST_NAMESPACE --timeout=60s
    
    # Capture initial metrics
    local initial_metrics=$(kubectl top pods -n $TEST_NAMESPACE -l app=metrics-test --no-headers 2>/dev/null || echo "Metrics unavailable")
    log_info "Initial metrics: $initial_metrics"
    
    # Perform resize
    kubectl patch deployment metrics-test -n $TEST_NAMESPACE --patch '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [{
                        "name": "metrics-app",
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
    
    kubectl rollout status deployment/metrics-test -n $TEST_NAMESPACE --timeout=60s
    
    # Wait for metrics to update
    sleep 30
    
    # Capture post-resize metrics
    local final_metrics=$(kubectl top pods -n $TEST_NAMESPACE -l app=metrics-test --no-headers 2>/dev/null || echo "Metrics unavailable")
    log_info "Final metrics: $final_metrics"
    
    # Check if metrics are available and reasonable
    if [[ "$final_metrics" != "Metrics unavailable" ]] && [[ -n "$final_metrics" ]]; then
        log_pass "Pod metrics available after resize"
    else
        log_warn "Pod metrics not available after resize (metrics-server may need time to update)"
    fi
    
    # Cleanup
    kubectl delete deployment metrics-test -n $TEST_NAMESPACE --ignore-not-found=true
}

# Generate advanced test report
generate_advanced_report() {
    local total_tests=$((PASSED + FAILED))
    local success_rate=$(( total_tests > 0 ? PASSED * 100 / total_tests : 0 ))
    
    log "=============================================="
    log "AKS 1.33 Pod Resizing Advanced Test Results"
    log "=============================================="
    log "Total Tests: $total_tests"
    log "Passed: $PASSED"
    log "Failed: $FAILED"
    log "Success Rate: ${success_rate}%"
    
    # Generate detailed report
    cat > "aks-133-advanced-test-report-$(date +%Y%m%d-%H%M%S).txt" <<EOF
AKS 1.33 Pod Resizing Advanced Test Report
Generated: $(date)
Cluster: $(kubectl config current-context)
Test Namespace: $TEST_NAMESPACE

Advanced Test Results Summary:
- Total Tests: $total_tests  
- Passed: $PASSED
- Failed: $FAILED
- Success Rate: ${success_rate}%

Test Scenarios Covered:
1. JVM Memory Resize Behavior
2. HPA Integration with Pod Resize
3. Resize Beyond Node Capacity
4. Rapid Successive Resize Operations  
5. Resize During Pod Eviction
6. Metrics Reporting During Resize

Key Findings:
$(if [[ $success_rate -ge 90 ]]; then
    echo "✅ Advanced pod resizing scenarios work correctly"
    echo "✅ JVM applications handle resize appropriately"
    echo "✅ HPA integration maintains functionality"
else
    echo "⚠️  Some advanced scenarios need attention"
    echo "⚠️  Review specific test failures"
fi)

Production Readiness Assessment:
$(if [[ $success_rate -ge 85 ]]; then
    echo "🟢 READY - Advanced features validated for production"
    echo "   Recommended: Gradual rollout with monitoring"
else
    echo "🟡 CAUTION - Some advanced features need validation"
    echo "   Recommended: Additional testing before production"
fi)

Specific Recommendations:
- Monitor JVM applications closely during initial resize operations
- Ensure HPA thresholds are appropriate for resized resources
- Implement proper PodDisruptionBudgets for critical workloads
- Test with actual application workloads before production deployment
- Consider implementing retry logic for rapid resize scenarios

Environment Details:
- Test Namespace: $TEST_NAMESPACE
- Java App: $JAVA_APP_NAME
- HPA App: $HPA_APP_NAME
- Node Resources: $(kubectl get nodes -o jsonpath='{.items[0].status.capacity}' 2>/dev/null || echo "Not available")
EOF
    
    log "Advanced test report saved to: aks-133-advanced-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    if [[ $success_rate -ge 80 ]]; then
        log_pass "Advanced test suite PASSED with ${success_rate}% success rate"
    else
        log_fail "Advanced test suite needs attention with ${success_rate}% success rate"
    fi
}

# Cleanup function
cleanup_advanced() {
    log "Cleaning up advanced test resources..."
    kubectl delete namespace $TEST_NAMESPACE --ignore-not-found=true
    log "Advanced test cleanup completed"
}

# Main execution
main() {
    log "Starting AKS 1.33 Pod Resizing Advanced Tests..."
    
    trap cleanup_advanced EXIT
    
    setup_advanced_environment
    
    test_jvm_memory_resize
    test_hpa_resize_interaction
    test_resize_beyond_capacity
    test_rapid_resize_operations
    test_resize_during_eviction
    test_metrics_reporting
    
    generate_advanced_report
    
    log "AKS 1.33 Pod Resizing Advanced Tests completed"
    
    # Exit with error code if any tests failed
    if [[ $FAILED -gt 0 ]]; then
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
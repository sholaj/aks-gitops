#!/bin/bash
# AKS 1.33 Pod Resizing Test Script v2
# Tests in-place pod resize using the resize subresource
# Based on LinkedIn article validation

set -euo pipefail

# Configuration
TEST_NAMESPACE="aks-133-resize-v2"
POD_NAME="resize-test-pod"
PASSED=0
FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-v2] $*"
}

log_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $*"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}❌ FAIL${NC}: $*"
    ((FAILED++))
}

log_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $*"
}

log_header() {
    echo -e "\n${BOLD}${BLUE}================================================${NC}"
    echo -e "${BOLD}${BLUE} $* ${NC}"
    echo -e "${BOLD}${BLUE}================================================${NC}\n"
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"
    
    # Critical: Check kubectl version for resize subresource support
    local kubectl_version=$(kubectl version --client 2>/dev/null | grep -o 'v1\.[0-9]*' | head -1)
    local version_num=${kubectl_version#v1.}
    
    if [[ $version_num -ge 34 ]]; then
        log_pass "kubectl version $kubectl_version supports resize subresource"
    else
        log_fail "kubectl version $kubectl_version does not support resize subresource (need v1.34+)"
        log "To fix: brew upgrade kubectl (macOS) or update kubectl to v1.34+"
        exit 1
    fi
    
    # Check cluster version
    local cluster_version=$(kubectl version 2>/dev/null | grep -o 'Server.*v1\.[0-9]*' | grep -o 'v1\.[0-9]*' || echo "")
    if [[ ${cluster_version#v1.} -ge 33 ]]; then
        log_pass "Cluster version $cluster_version supports pod resizing"
    else
        log_fail "Cluster version $cluster_version may not support pod resizing (need v1.33+)"
        exit 1
    fi
    
    # Check cluster connectivity
    if kubectl cluster-info &> /dev/null; then
        log_pass "Connected to Kubernetes cluster"
    else
        log_fail "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# Setup test environment
setup_test_environment() {
    log_header "Setting Up Test Environment"
    
    # Create namespace
    kubectl create namespace $TEST_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    log_pass "Namespace '$TEST_NAMESPACE' ready"
    
    # Create test pod with resize policy
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: $TEST_NAMESPACE
  labels:
    app: resize-test
    test: v2
spec:
  containers:
  - name: test-container
    image: nginx:1.21
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
    resizePolicy:
    - resourceName: cpu
      restartPolicy: NotRequired
    - resourceName: memory
      restartPolicy: NotRequired
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 10
EOF
    
    # Wait for pod to be ready
    kubectl wait --for=condition=ready pod/$POD_NAME -n $TEST_NAMESPACE --timeout=60s
    log_pass "Test pod '$POD_NAME' is ready"
    
    # Record initial state
    log "Initial pod state:"
    kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o json | jq -r '.spec.containers[0].resources'
}

# Test CPU resize
test_cpu_resize() {
    log_header "Testing CPU Resize (100m → 250m)"
    
    # Get initial state
    local initial_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
    local initial_pod_uid=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.metadata.uid}')
    
    log "Initial restart count: $initial_restart_count"
    log "Pod UID: $initial_pod_uid"
    
    # Perform resize using subresource
    log "Executing CPU resize..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch '{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"cpu":"250m"},"limits":{"cpu":"500m"}}}]}}'; then
        log_pass "CPU resize command executed successfully"
    else
        log_fail "CPU resize command failed"
        return 1
    fi
    
    # Wait for resize to complete
    sleep 5
    
    # Verify resize
    local new_cpu_request=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
    local new_cpu_limit=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
    local new_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
    local new_pod_uid=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.metadata.uid}')
    
    # Check CPU values
    if [[ "$new_cpu_request" == "250m" && "$new_cpu_limit" == "500m" ]]; then
        log_pass "CPU resources updated correctly (requests: $new_cpu_request, limits: $new_cpu_limit)"
    else
        log_fail "CPU resources not updated correctly (requests: $new_cpu_request, limits: $new_cpu_limit)"
    fi
    
    # Check for restarts
    if [[ "$initial_restart_count" == "$new_restart_count" ]]; then
        log_pass "No pod restarts during CPU resize (count: $new_restart_count)"
    else
        log_fail "Pod restarted during CPU resize (before: $initial_restart_count, after: $new_restart_count)"
    fi
    
    # Check pod identity
    if [[ "$initial_pod_uid" == "$new_pod_uid" ]]; then
        log_pass "Pod maintained same identity (UID unchanged)"
    else
        log_fail "Pod was recreated (UID changed)"
    fi
}

# Test memory resize
test_memory_resize() {
    log_header "Testing Memory Resize (64Mi → 256Mi)"
    
    # Get initial state
    local initial_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
    local initial_container_id=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].containerID}')
    
    log "Initial restart count: $initial_restart_count"
    
    # Perform resize using subresource
    log "Executing memory resize..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch '{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"memory":"256Mi"},"limits":{"memory":"512Mi"}}}]}}'; then
        log_pass "Memory resize command executed successfully"
    else
        log_fail "Memory resize command failed"
        return 1
    fi
    
    # Wait for resize to complete
    sleep 5
    
    # Verify resize
    local new_memory_request=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.memory}')
    local new_memory_limit=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.limits.memory}')
    local new_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
    local new_container_id=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].containerID}')
    
    # Check memory values
    if [[ "$new_memory_request" == "256Mi" && "$new_memory_limit" == "512Mi" ]]; then
        log_pass "Memory resources updated correctly (requests: $new_memory_request, limits: $new_memory_limit)"
    else
        log_fail "Memory resources not updated correctly (requests: $new_memory_request, limits: $new_memory_limit)"
    fi
    
    # Check for restarts
    if [[ "$initial_restart_count" == "$new_restart_count" ]]; then
        log_pass "No pod restarts during memory resize (count: $new_restart_count)"
    else
        log_fail "Pod restarted during memory resize (before: $initial_restart_count, after: $new_restart_count)"
    fi
    
    # Check container identity
    if [[ "$initial_container_id" == "$new_container_id" ]]; then
        log_pass "Container maintained same ID (no recreation)"
    else
        log_warn "Container ID changed (may indicate container restart)"
    fi
}

# Test combined resize
test_combined_resize() {
    log_header "Testing Combined CPU+Memory Resize"
    
    # Get initial state
    local initial_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
    
    log "Initial restart count: $initial_restart_count"
    
    # Perform combined resize
    log "Executing combined CPU+Memory resize..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch '{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"cpu":"300m","memory":"384Mi"},"limits":{"cpu":"600m","memory":"768Mi"}}}]}}'; then
        log_pass "Combined resize command executed successfully"
    else
        log_fail "Combined resize command failed"
        return 1
    fi
    
    # Wait for resize to complete
    sleep 5
    
    # Verify resize
    local new_cpu_request=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
    local new_memory_request=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.memory}')
    local new_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
    
    # Check values
    if [[ "$new_cpu_request" == "300m" && "$new_memory_request" == "384Mi" ]]; then
        log_pass "Combined resources updated correctly (CPU: $new_cpu_request, Memory: $new_memory_request)"
    else
        log_fail "Combined resources not updated correctly (CPU: $new_cpu_request, Memory: $new_memory_request)"
    fi
    
    # Check for restarts
    if [[ "$initial_restart_count" == "$new_restart_count" ]]; then
        log_pass "No pod restarts during combined resize (count: $new_restart_count)"
    else
        log_fail "Pod restarted during combined resize (before: $initial_restart_count, after: $new_restart_count)"
    fi
}

# Test resize without subresource (should fail)
test_resize_without_subresource() {
    log_header "Testing Resize Without Subresource (Should Fail)"
    
    log "Attempting direct pod patch without --subresource resize..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --patch '{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"cpu":"400m"}}}]}}' 2>/dev/null; then
        log_fail "Direct pod patch succeeded (unexpected - should be forbidden)"
    else
        log_pass "Direct pod patch failed as expected (resize requires subresource)"
    fi
}

# Check allocated resources
check_allocated_resources() {
    log_header "Checking Allocated Resources"
    
    # Get allocated resources from status
    local allocated=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o json | jq -r '.status.containerStatuses[0].allocatedResources // "Not available"')
    
    if [[ "$allocated" != "Not available" && "$allocated" != "null" ]]; then
        log_pass "Allocated resources tracked in pod status:"
        echo "$allocated" | jq .
    else
        log_warn "Allocated resources not available in pod status (may require newer kubelet)"
    fi
    
    # Show final resource state
    log "Final pod resources:"
    kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o json | jq -r '.spec.containers[0].resources'
}

# Cleanup
cleanup() {
    log_header "Cleanup"
    
    if kubectl delete namespace $TEST_NAMESPACE --timeout=60s 2>/dev/null; then
        log_pass "Test namespace deleted"
    else
        log_warn "Could not delete test namespace"
    fi
}

# Generate report
generate_report() {
    log_header "Test Summary Report"
    
    local total=$((PASSED + FAILED))
    local success_rate=0
    if [[ $total -gt 0 ]]; then
        success_rate=$((PASSED * 100 / total))
    fi
    
    echo -e "${BOLD}Results:${NC}"
    echo -e "  Total Tests: $total"
    echo -e "  Passed: ${GREEN}$PASSED${NC}"
    echo -e "  Failed: ${RED}$FAILED${NC}"
    echo -e "  Success Rate: ${BOLD}${success_rate}%${NC}"
    
    if [[ $FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}${BOLD}✅ All tests passed!${NC}"
        echo -e "${GREEN}In-place pod resizing is working correctly in this AKS cluster.${NC}"
    elif [[ $success_rate -ge 75 ]]; then
        echo -e "\n${YELLOW}${BOLD}⚠️  Most tests passed with some issues${NC}"
        echo -e "${YELLOW}Pod resizing is partially working. Review failed tests for details.${NC}"
    else
        echo -e "\n${RED}${BOLD}❌ Tests failed${NC}"
        echo -e "${RED}Pod resizing is not working as expected. Check cluster configuration.${NC}"
    fi
    
    echo -e "\n${BOLD}Key Requirements for Pod Resizing:${NC}"
    echo "  • Kubernetes 1.33+ cluster"
    echo "  • kubectl v1.34+ client"
    echo "  • ResizePolicy configured in pod spec"
    echo "  • Linux nodes (Windows not supported)"
    echo "  • Use --subresource resize flag"
}

# Main execution
main() {
    log_header "AKS 1.33 Pod Resizing Test v2"
    log "Testing in-place pod resizing with resize subresource"
    
    # Set exit trap for cleanup
    trap cleanup EXIT
    
    # Run tests
    check_prerequisites
    setup_test_environment
    test_cpu_resize
    test_memory_resize
    test_combined_resize
    test_resize_without_subresource
    check_allocated_resources
    
    # Generate report
    generate_report
    
    # Exit with appropriate code
    if [[ $FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"
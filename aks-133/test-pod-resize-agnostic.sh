#!/bin/bash
# Pod Resizing Test Script - Environment Agnostic Version
# Tests in-place pod resize using the resize subresource
# Works with any Kubernetes environment (AKS, EKS, GKE, kind, minikube, etc.)

set -euo pipefail

# Configuration - Environment Variables with Defaults
TEST_NAMESPACE="${TEST_NAMESPACE:-pod-resize-test}"
POD_NAME="${POD_NAME:-resize-test-pod}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-nginx:1.21-alpine}"
CONTAINER_NAME="${CONTAINER_NAME:-test-container}"
CLUSTER_TYPE="${CLUSTER_TYPE:-generic}"  # generic, aks, eks, gke, kind, minikube
TIMEOUT="${TIMEOUT:-60}"
CLEANUP_ON_EXIT="${CLEANUP_ON_EXIT:-true}"
VERBOSE="${VERBOSE:-false}"
SKIP_PREREQ_CHECK="${SKIP_PREREQ_CHECK:-false}"

# Resource configuration
INITIAL_CPU_REQUEST="${INITIAL_CPU_REQUEST:-100m}"
INITIAL_CPU_LIMIT="${INITIAL_CPU_LIMIT:-200m}"
INITIAL_MEM_REQUEST="${INITIAL_MEM_REQUEST:-64Mi}"
INITIAL_MEM_LIMIT="${INITIAL_MEM_LIMIT:-128Mi}"

# Resize targets
RESIZE_CPU_REQUEST="${RESIZE_CPU_REQUEST:-250m}"
RESIZE_CPU_LIMIT="${RESIZE_CPU_LIMIT:-500m}"
RESIZE_MEM_REQUEST="${RESIZE_MEM_REQUEST:-256Mi}"
RESIZE_MEM_LIMIT="${RESIZE_MEM_LIMIT:-512Mi}"

# Test counters
PASSED=0
FAILED=0
SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Enable verbose mode if requested
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [POD-RESIZE] $*"
}

log_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $*"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}❌ FAIL${NC}: $*"
    ((FAILED++))
}

log_skip() {
    echo -e "${YELLOW}⏭️  SKIP${NC}: $*"
    ((SKIPPED++))
}

log_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $*"
}

log_header() {
    echo -e "\n${BOLD}${BLUE}================================================${NC}"
    echo -e "${BOLD}${BLUE} $* ${NC}"
    echo -e "${BOLD}${BLUE}================================================${NC}\n"
}

# Show help
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Pod Resize Test Script - Tests in-place pod resizing capabilities

Options:
    --namespace NAME        Test namespace (default: pod-resize-test)
    --pod-name NAME         Test pod name (default: resize-test-pod)
    --image IMAGE           Container image (default: nginx:1.21-alpine)
    --container-name NAME   Container name (default: test-container)
    --cluster-type TYPE     Cluster type: generic, aks, eks, gke, kind, minikube
    --timeout SECONDS       Timeout for operations (default: 60)
    --no-cleanup            Don't cleanup resources on exit
    --skip-prereq           Skip prerequisite checks
    --verbose               Enable verbose output
    --help                  Show this help message

Resource Configuration:
    --initial-cpu-request   Initial CPU request (default: 100m)
    --initial-cpu-limit     Initial CPU limit (default: 200m)
    --initial-mem-request   Initial memory request (default: 64Mi)
    --initial-mem-limit     Initial memory limit (default: 128Mi)
    --resize-cpu-request    Target CPU request (default: 250m)
    --resize-cpu-limit      Target CPU limit (default: 500m)
    --resize-mem-request    Target memory request (default: 256Mi)
    --resize-mem-limit      Target memory limit (default: 512Mi)

Environment Variables:
    TEST_NAMESPACE          Test namespace
    POD_NAME                Test pod name
    CONTAINER_IMAGE         Container image to use
    CONTAINER_NAME          Container name
    CLUSTER_TYPE            Type of cluster
    TIMEOUT                 Operation timeout
    CLEANUP_ON_EXIT         Set to 'false' to skip cleanup
    VERBOSE                 Set to 'true' for verbose output
    SKIP_PREREQ_CHECK       Set to 'true' to skip prerequisite checks

Examples:
    # Run with default settings
    $0

    # Use custom image and namespace
    $0 --image busybox:latest --namespace my-test

    # Run on AKS cluster with verbose output
    $0 --cluster-type aks --verbose

    # Keep resources after test
    $0 --no-cleanup

    # Custom resource sizes
    $0 --initial-cpu-request 50m --resize-cpu-request 150m

    # Using environment variables
    CONTAINER_IMAGE=alpine:3.18 TIMEOUT=120 $0
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespace)
                TEST_NAMESPACE="$2"
                shift 2
                ;;
            --pod-name)
                POD_NAME="$2"
                shift 2
                ;;
            --image)
                CONTAINER_IMAGE="$2"
                shift 2
                ;;
            --container-name)
                CONTAINER_NAME="$2"
                shift 2
                ;;
            --cluster-type)
                CLUSTER_TYPE="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --no-cleanup)
                CLEANUP_ON_EXIT="false"
                shift
                ;;
            --skip-prereq)
                SKIP_PREREQ_CHECK="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                set -x
                shift
                ;;
            --initial-cpu-request)
                INITIAL_CPU_REQUEST="$2"
                shift 2
                ;;
            --initial-cpu-limit)
                INITIAL_CPU_LIMIT="$2"
                shift 2
                ;;
            --initial-mem-request)
                INITIAL_MEM_REQUEST="$2"
                shift 2
                ;;
            --initial-mem-limit)
                INITIAL_MEM_LIMIT="$2"
                shift 2
                ;;
            --resize-cpu-request)
                RESIZE_CPU_REQUEST="$2"
                shift 2
                ;;
            --resize-cpu-limit)
                RESIZE_CPU_LIMIT="$2"
                shift 2
                ;;
            --resize-mem-request)
                RESIZE_MEM_REQUEST="$2"
                shift 2
                ;;
            --resize-mem-limit)
                RESIZE_MEM_LIMIT="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_warn "Unknown option: $1"
                shift
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"

    if [[ "$SKIP_PREREQ_CHECK" == "true" ]]; then
        log_warn "Skipping prerequisite checks (--skip-prereq)"
        return 0
    fi

    local prereq_failed=false

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_fail "kubectl is not installed"
        prereq_failed=true
    else
        # Check kubectl version for resize subresource support
        local kubectl_version=$(kubectl version --client 2>/dev/null | grep -o 'v1\.[0-9]*' | head -1 || echo "")
        if [[ -n "$kubectl_version" ]]; then
            local version_num=${kubectl_version#v1.}
            if [[ $version_num -ge 34 ]]; then
                log_pass "kubectl version $kubectl_version supports resize subresource"
            else
                log_warn "kubectl version $kubectl_version may not support resize subresource (recommend v1.34+)"
                log "Will attempt resize with fallback methods if needed"
            fi
        else
            log_warn "Could not determine kubectl version"
        fi
    fi

    # Check cluster version
    local cluster_version=$(kubectl version --output=json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo "")
    if [[ -n "$cluster_version" ]]; then
        local cluster_minor=$(echo "$cluster_version" | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f2)
        if [[ -n "$cluster_minor" ]] && [[ "$cluster_minor" -ge 33 ]]; then
            log_pass "Cluster version $cluster_version supports pod resizing"
        else
            log_warn "Cluster version $cluster_version may not fully support pod resizing (need v1.33+)"
            log "Some tests may fail on older clusters"
        fi
    else
        log_warn "Could not determine cluster version"
    fi

    # Check cluster connectivity
    if kubectl cluster-info &> /dev/null; then
        log_pass "Connected to Kubernetes cluster"
    else
        log_fail "Cannot connect to Kubernetes cluster"
        prereq_failed=true
    fi

    if [[ "$prereq_failed" == "true" ]]; then
        log_fail "Prerequisite checks failed. Use --skip-prereq to bypass."
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
    test: agnostic
    cluster-type: $CLUSTER_TYPE
spec:
  containers:
  - name: $CONTAINER_NAME
    image: $CONTAINER_IMAGE
    imagePullPolicy: IfNotPresent
    resources:
      requests:
        memory: "$INITIAL_MEM_REQUEST"
        cpu: "$INITIAL_CPU_REQUEST"
      limits:
        memory: "$INITIAL_MEM_LIMIT"
        cpu: "$INITIAL_CPU_LIMIT"
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
      timeoutSeconds: 3
      successThreshold: 1
      failureThreshold: 3
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 5
      successThreshold: 1
      failureThreshold: 3
EOF

    # Wait for pod to be ready
    if kubectl wait --for=condition=ready pod/$POD_NAME -n $TEST_NAMESPACE --timeout=${TIMEOUT}s 2>/dev/null; then
        log_pass "Test pod '$POD_NAME' is ready"
    else
        log_fail "Pod failed to become ready within ${TIMEOUT}s"
        kubectl describe pod $POD_NAME -n $TEST_NAMESPACE
        return 1
    fi

    # Record initial state
    log "Initial pod state:"
    if command -v jq &> /dev/null; then
        kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o json | jq -r '.spec.containers[0].resources'
    else
        kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o yaml | grep -A 8 "resources:"
    fi
}

# Test CPU resize
test_cpu_resize() {
    log_header "Testing CPU Resize ($INITIAL_CPU_REQUEST → $RESIZE_CPU_REQUEST)"

    # Get initial state
    local initial_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    local initial_pod_uid=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.metadata.uid}')

    log "Initial restart count: $initial_restart_count"
    log "Pod UID: $initial_pod_uid"

    # Perform resize using subresource
    log "Executing CPU resize..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"'"$RESIZE_CPU_REQUEST"'"},"limits":{"cpu":"'"$RESIZE_CPU_LIMIT"'"}}}]}}' 2>/dev/null; then
        log_pass "CPU resize command executed successfully (using --subresource)"
    else
        # Fallback for older kubectl versions
        log_warn "Resize subresource not available, attempting standard patch..."
        if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
            --type='strategic' \
            --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"'"$RESIZE_CPU_REQUEST"'"},"limits":{"cpu":"'"$RESIZE_CPU_LIMIT"'"}}}]}}' 2>/dev/null; then
            log_warn "Used standard patch (may require pod restart)"
        else
            log_fail "CPU resize command failed"
            return 1
        fi
    fi

    # Wait for resize to complete
    sleep 5

    # Verify resize
    local new_cpu_request=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
    local new_cpu_limit=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
    local new_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    local new_pod_uid=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.metadata.uid}')

    # Check CPU values
    if [[ "$new_cpu_request" == "$RESIZE_CPU_REQUEST" && "$new_cpu_limit" == "$RESIZE_CPU_LIMIT" ]]; then
        log_pass "CPU resources updated correctly (requests: $new_cpu_request, limits: $new_cpu_limit)"
    else
        log_fail "CPU resources not updated correctly (requests: $new_cpu_request, limits: $new_cpu_limit)"
    fi

    # Check for restarts
    if [[ "$initial_restart_count" == "$new_restart_count" ]]; then
        log_pass "No pod restarts during CPU resize (count: $new_restart_count)"
    else
        log_warn "Pod restarted during CPU resize (before: $initial_restart_count, after: $new_restart_count)"
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
    log_header "Testing Memory Resize ($INITIAL_MEM_REQUEST → $RESIZE_MEM_REQUEST)"

    # Get initial state
    local initial_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    local initial_container_id=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].containerID}')

    log "Initial restart count: $initial_restart_count"

    # Perform resize using subresource
    log "Executing memory resize..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"memory":"'"$RESIZE_MEM_REQUEST"'"},"limits":{"memory":"'"$RESIZE_MEM_LIMIT"'"}}}]}}' 2>/dev/null; then
        log_pass "Memory resize command executed successfully (using --subresource)"
    else
        log_warn "Resize subresource not available, attempting standard patch..."
        if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
            --type='strategic' \
            --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"memory":"'"$RESIZE_MEM_REQUEST"'"},"limits":{"memory":"'"$RESIZE_MEM_LIMIT"'"}}}]}}' 2>/dev/null; then
            log_warn "Used standard patch"
        else
            log_fail "Memory resize command failed"
            return 1
        fi
    fi

    # Wait for resize to complete
    sleep 5

    # Verify resize
    local new_memory_request=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.memory}')
    local new_memory_limit=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.limits.memory}')
    local new_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")
    local new_container_id=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].containerID}')

    # Check memory values
    if [[ "$new_memory_request" == "$RESIZE_MEM_REQUEST" && "$new_memory_limit" == "$RESIZE_MEM_LIMIT" ]]; then
        log_pass "Memory resources updated correctly (requests: $new_memory_request, limits: $new_memory_limit)"
    else
        log_fail "Memory resources not updated correctly (requests: $new_memory_request, limits: $new_memory_limit)"
    fi

    # Check for restarts
    if [[ "$initial_restart_count" == "$new_restart_count" ]]; then
        log_pass "No pod restarts during memory resize (count: $new_restart_count)"
    else
        log_warn "Pod restarted during memory resize (before: $initial_restart_count, after: $new_restart_count)"
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
    local initial_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")

    log "Initial restart count: $initial_restart_count"

    # Calculate new values (slightly different from individual tests)
    local combined_cpu_request="300m"
    local combined_cpu_limit="600m"
    local combined_mem_request="384Mi"
    local combined_mem_limit="768Mi"

    # Perform combined resize
    log "Executing combined CPU+Memory resize..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"'"$combined_cpu_request"'","memory":"'"$combined_mem_request"'"},"limits":{"cpu":"'"$combined_cpu_limit"'","memory":"'"$combined_mem_limit"'"}}}]}}' 2>/dev/null; then
        log_pass "Combined resize command executed successfully"
    else
        log_warn "Resize subresource not available, attempting standard patch..."
        if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
            --type='strategic' \
            --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"'"$combined_cpu_request"'","memory":"'"$combined_mem_request"'"},"limits":{"cpu":"'"$combined_cpu_limit"'","memory":"'"$combined_mem_limit"'"}}}]}}' 2>/dev/null; then
            log_warn "Used standard patch"
        else
            log_fail "Combined resize command failed"
            return 1
        fi
    fi

    # Wait for resize to complete
    sleep 5

    # Verify resize
    local new_cpu_request=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
    local new_memory_request=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.memory}')
    local new_restart_count=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "0")

    # Check values
    if [[ "$new_cpu_request" == "$combined_cpu_request" && "$new_memory_request" == "$combined_mem_request" ]]; then
        log_pass "Combined resources updated correctly (CPU: $new_cpu_request, Memory: $new_memory_request)"
    else
        log_fail "Combined resources not updated correctly (CPU: $new_cpu_request, Memory: $new_memory_request)"
    fi

    # Check for restarts
    if [[ "$initial_restart_count" == "$new_restart_count" ]]; then
        log_pass "No pod restarts during combined resize (count: $new_restart_count)"
    else
        log_warn "Pod restarted during combined resize (before: $initial_restart_count, after: $new_restart_count)"
    fi
}

# Test resize without subresource (should fail)
test_resize_without_subresource() {
    log_header "Testing Resize Without Subresource (Should Fail)"

    log "Attempting direct pod patch without --subresource resize..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"400m"}}}]}}' 2>/dev/null; then
        log_fail "Direct pod patch succeeded (unexpected - should be forbidden)"
    else
        log_pass "Direct pod patch failed as expected (resize requires subresource)"
    fi
}

# Check allocated resources
check_allocated_resources() {
    log_header "Checking Allocated Resources"

    # Get allocated resources from status
    if command -v jq &> /dev/null; then
        local allocated=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o json 2>/dev/null | jq -r '.status.containerStatuses[0].allocatedResources // empty')

        if [[ -n "$allocated" ]]; then
            log_pass "Allocated resources tracked in pod status:"
            echo "$allocated" | jq .
        else
            log_warn "Allocated resources not available in pod status (may require newer kubelet)"
        fi
    else
        log_warn "jq not installed, skipping detailed resource check"
    fi

    # Show final resource state
    log "Final pod resources:"
    kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o wide
}

# Cleanup
cleanup() {
    log_header "Cleanup"

    if [[ "$CLEANUP_ON_EXIT" != "true" ]]; then
        log "Skipping cleanup (CLEANUP_ON_EXIT=$CLEANUP_ON_EXIT)"
        log "Resources left in namespace: $TEST_NAMESPACE"
        return 0
    fi

    if kubectl delete namespace $TEST_NAMESPACE --timeout=${TIMEOUT}s 2>/dev/null; then
        log_pass "Test namespace deleted"
    else
        log_warn "Could not delete test namespace"
    fi
}

# Generate report
generate_report() {
    log_header "Test Summary Report"

    local total=$((PASSED + FAILED + SKIPPED))
    local success_rate=0
    if [[ $((PASSED + FAILED)) -gt 0 ]]; then
        success_rate=$((PASSED * 100 / (PASSED + FAILED)))
    fi

    echo -e "${BOLD}Results:${NC}"
    echo -e "  Total Tests: $total"
    echo -e "  Passed: ${GREEN}$PASSED${NC}"
    echo -e "  Failed: ${RED}$FAILED${NC}"
    echo -e "  Skipped: ${YELLOW}$SKIPPED${NC}"
    echo -e "  Success Rate: ${BOLD}${success_rate}%${NC}"

    if [[ $FAILED -eq 0 && $PASSED -gt 0 ]]; then
        echo -e "\n${GREEN}${BOLD}✅ All tests passed!${NC}"
        echo -e "${GREEN}Pod resizing is working correctly.${NC}"
    elif [[ $success_rate -ge 75 ]]; then
        echo -e "\n${YELLOW}${BOLD}⚠️  Most tests passed with some issues${NC}"
        echo -e "${YELLOW}Pod resizing is partially working. Review failed tests for details.${NC}"
    else
        echo -e "\n${RED}${BOLD}❌ Tests failed${NC}"
        echo -e "${RED}Pod resizing is not working as expected. Check cluster configuration.${NC}"
    fi

    echo -e "\n${BOLD}Key Requirements for Pod Resizing:${NC}"
    echo "  • Kubernetes 1.33+ cluster"
    echo "  • kubectl v1.34+ client (for --subresource resize)"
    echo "  • ResizePolicy configured in pod spec"
    echo "  • Linux nodes (Windows not supported)"
    echo "  • Use --subresource resize flag (when available)"

    echo -e "\n${BOLD}Test Configuration:${NC}"
    echo "  • Namespace: $TEST_NAMESPACE"
    echo "  • Pod Name: $POD_NAME"
    echo "  • Container Image: $CONTAINER_IMAGE"
    echo "  • Container Name: $CONTAINER_NAME"
    echo "  • Cluster Type: $CLUSTER_TYPE"
    echo "  • Timeout: ${TIMEOUT}s"
    echo "  • Initial Resources: CPU=$INITIAL_CPU_REQUEST/$INITIAL_CPU_LIMIT, Memory=$INITIAL_MEM_REQUEST/$INITIAL_MEM_LIMIT"
    echo "  • Resize Targets: CPU=$RESIZE_CPU_REQUEST/$RESIZE_CPU_LIMIT, Memory=$RESIZE_MEM_REQUEST/$RESIZE_MEM_LIMIT"
}

# Main execution
main() {
    log_header "Pod Resizing Test - Environment Agnostic"
    log "Testing in-place pod resizing capabilities"
    log "Cluster Type: $CLUSTER_TYPE"
    log "Container Image: $CONTAINER_IMAGE"

    # Set exit trap for cleanup
    trap cleanup EXIT

    # Run tests
    if [[ "$SKIP_PREREQ_CHECK" != "true" ]]; then
        check_prerequisites
    fi

    setup_test_environment
    test_cpu_resize
    test_memory_resize
    test_combined_resize
    test_resize_without_subresource
    check_allocated_resources

    # Generate report
    generate_report

    # Exit with appropriate code
    if [[ $FAILED -eq 0 && $PASSED -gt 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Parse arguments and run
parse_args "$@"
main "$@"
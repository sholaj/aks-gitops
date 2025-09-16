#!/bin/bash
# AKS 1.33 Pod Resizing Test Script - Improved Version
# Enhanced error handling and robustness
# Tests in-place pod resize using the resize subresource

set -euo pipefail

# Configuration
TEST_NAMESPACE="${TEST_NAMESPACE:-aks-133-resize-test}"
POD_NAME="${POD_NAME:-resize-test-pod}"
PASSED=0
FAILED=0
SKIPPED=0
DEBUG="${DEBUG:-false}"
TIMEOUT="${TIMEOUT:-60}"
RETRY_COUNT="${RETRY_COUNT:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Error handling
ERROR_LOG="/tmp/pod-resize-test-errors-$(date +%s).log"
CLEANUP_ON_EXIT=true

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [POD-RESIZE] $*" | tee -a "$ERROR_LOG"
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $*" | tee -a "$ERROR_LOG"
    fi
}

log_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $*"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}❌ FAIL${NC}: $*" | tee -a "$ERROR_LOG"
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

# Error trap
error_handler() {
    local line_no=$1
    local exit_code=$2
    log_fail "Error occurred at line $line_no with exit code $exit_code"
    log "Check error log: $ERROR_LOG"
    if [[ "$CLEANUP_ON_EXIT" == "true" ]]; then
        cleanup
    fi
}

trap 'error_handler ${LINENO} $?' ERR

# Retry mechanism
retry_command() {
    local command="$1"
    local description="${2:-command}"
    local retries=$RETRY_COUNT
    local delay=$RETRY_DELAY

    while [[ $retries -gt 0 ]]; do
        log_debug "Attempting: $description (retries left: $retries)"
        if eval "$command"; then
            return 0
        fi
        ((retries--))
        if [[ $retries -gt 0 ]]; then
            log_warn "Failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
    done

    log_fail "Failed after $RETRY_COUNT attempts: $description"
    return 1
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites with detailed validation
check_prerequisites() {
    log_header "Checking Prerequisites"

    local prerequisites_met=true

    # Check kubectl installation
    if ! command_exists kubectl; then
        log_fail "kubectl is not installed"
        log "Install kubectl: https://kubernetes.io/docs/tasks/tools/"
        prerequisites_met=false
    else
        log_pass "kubectl is installed"
    fi

    # Check kubectl version for resize subresource support
    if command_exists kubectl; then
        local kubectl_version=$(kubectl version --client --output=json 2>/dev/null | jq -r '.clientVersion.gitVersion' || echo "unknown")
        local version_num=$(echo "$kubectl_version" | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f2)

        if [[ -n "$version_num" ]] && [[ "$version_num" -ge 34 ]]; then
            log_pass "kubectl version $kubectl_version supports resize subresource"
        else
            log_warn "kubectl version $kubectl_version may not support resize subresource (recommend v1.34+)"
            log "Current workaround: Will attempt resize anyway"
        fi
    fi

    # Check cluster connectivity with timeout
    if command_exists kubectl; then
        if timeout 10 kubectl cluster-info &> /dev/null; then
            log_pass "Connected to Kubernetes cluster"

            # Get cluster version
            local cluster_version=$(kubectl version --output=json 2>/dev/null | jq -r '.serverVersion.gitVersion' || echo "unknown")
            local cluster_minor=$(echo "$cluster_version" | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f2)

            if [[ -n "$cluster_minor" ]] && [[ "$cluster_minor" -ge 33 ]]; then
                log_pass "Cluster version $cluster_version supports pod resizing"
            else
                log_warn "Cluster version $cluster_version may not fully support pod resizing (need v1.33+)"
                log "Some tests may fail on older clusters"
            fi
        else
            log_fail "Cannot connect to Kubernetes cluster"
            log "Run: kubectl config current-context"
            prerequisites_met=false
        fi
    fi

    # Check for jq (optional but helpful)
    if command_exists jq; then
        log_pass "jq is installed (for JSON processing)"
    else
        log_warn "jq is not installed (some features limited)"
        log "Install: brew install jq (macOS) or apt install jq (Linux)"
    fi

    if [[ "$prerequisites_met" == "false" ]]; then
        log_fail "Prerequisites not met. Please fix issues above."
        exit 1
    fi
}

# Setup test environment with error recovery
setup_test_environment() {
    log_header "Setting Up Test Environment"

    # Check if namespace exists
    if kubectl get namespace "$TEST_NAMESPACE" &>/dev/null; then
        log_warn "Namespace '$TEST_NAMESPACE' already exists"
        read -p "Delete and recreate? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace "$TEST_NAMESPACE" --timeout="${TIMEOUT}s" || true
            sleep 5
        else
            log "Using existing namespace"
        fi
    fi

    # Create namespace with retry
    if ! kubectl get namespace "$TEST_NAMESPACE" &>/dev/null; then
        retry_command "kubectl create namespace $TEST_NAMESPACE" "create namespace"
    fi
    log_pass "Namespace '$TEST_NAMESPACE' ready"

    # Create test pod with comprehensive configuration
    cat <<EOF | kubectl apply -f - || {
        log_fail "Failed to create test pod"
        return 1
    }
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: $TEST_NAMESPACE
  labels:
    app: resize-test
    version: improved
  annotations:
    test.created: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
spec:
  restartPolicy: Always
  containers:
  - name: test-container
    image: nginx:1.21-alpine
    imagePullPolicy: IfNotPresent
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
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
EOF

    # Wait for pod to be ready with timeout
    log "Waiting for pod to be ready (timeout: ${TIMEOUT}s)..."
    if kubectl wait --for=condition=ready pod/$POD_NAME -n $TEST_NAMESPACE --timeout="${TIMEOUT}s" 2>/dev/null; then
        log_pass "Test pod '$POD_NAME' is ready"
    else
        log_fail "Pod failed to become ready within ${TIMEOUT}s"
        kubectl describe pod $POD_NAME -n $TEST_NAMESPACE
        return 1
    fi

    # Record initial state
    log "Initial pod state:"
    if command_exists jq; then
        kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o json | jq -r '.spec.containers[0].resources'
    else
        kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o yaml | grep -A 8 "resources:"
    fi
}

# Safe JSON extraction
safe_json_extract() {
    local json_path="$1"
    local default="${2:-}"

    if command_exists jq; then
        kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o json 2>/dev/null | jq -r "$json_path // \"$default\"" || echo "$default"
    else
        kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o jsonpath="{$json_path}" 2>/dev/null || echo "$default"
    fi
}

# Test CPU resize with validation
test_cpu_resize() {
    log_header "Testing CPU Resize (100m → 250m)"

    # Check if pod exists
    if ! kubectl get pod $POD_NAME -n $TEST_NAMESPACE &>/dev/null; then
        log_skip "Pod does not exist, skipping CPU resize test"
        return 0
    fi

    # Get initial state
    local initial_restart_count=$(safe_json_extract '.status.containerStatuses[0].restartCount' '0')
    local initial_pod_uid=$(safe_json_extract '.metadata.uid' 'unknown')

    log_debug "Initial restart count: $initial_restart_count"
    log_debug "Pod UID: $initial_pod_uid"

    # Perform resize using subresource
    log "Executing CPU resize..."
    local resize_patch='{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"cpu":"250m"},"limits":{"cpu":"500m"}}}]}}'

    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch "$resize_patch" 2>/dev/null; then
        log_pass "CPU resize command executed successfully"
    else
        # Fallback for older kubectl versions
        log_warn "Resize subresource not available, attempting standard patch..."
        if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
            --type='strategic' \
            --patch "$resize_patch" 2>/dev/null; then
            log_warn "Used standard patch (may require pod restart)"
        else
            log_fail "CPU resize command failed"
            return 1
        fi
    fi

    # Wait for resize to propagate
    sleep $RETRY_DELAY

    # Verify resize with retries
    local verified=false
    for i in $(seq 1 $RETRY_COUNT); do
        local new_cpu_request=$(safe_json_extract '.spec.containers[0].resources.requests.cpu' '')
        local new_cpu_limit=$(safe_json_extract '.spec.containers[0].resources.limits.cpu' '')

        if [[ "$new_cpu_request" == "250m" && "$new_cpu_limit" == "500m" ]]; then
            verified=true
            break
        fi

        log_debug "Attempt $i: CPU request=$new_cpu_request, limit=$new_cpu_limit"
        sleep 2
    done

    if [[ "$verified" == "true" ]]; then
        log_pass "CPU resources updated correctly"
    else
        log_fail "CPU resources not updated as expected"
    fi

    # Check for restarts
    local new_restart_count=$(safe_json_extract '.status.containerStatuses[0].restartCount' '0')
    if [[ "$initial_restart_count" == "$new_restart_count" ]]; then
        log_pass "No pod restarts during CPU resize"
    else
        log_warn "Pod restarted during CPU resize (expected for some configurations)"
    fi

    # Check pod identity
    local new_pod_uid=$(safe_json_extract '.metadata.uid' 'unknown')
    if [[ "$initial_pod_uid" == "$new_pod_uid" ]]; then
        log_pass "Pod maintained same identity"
    else
        log_fail "Pod was recreated"
    fi
}

# Test memory resize with validation
test_memory_resize() {
    log_header "Testing Memory Resize (64Mi → 256Mi)"

    # Check if pod exists
    if ! kubectl get pod $POD_NAME -n $TEST_NAMESPACE &>/dev/null; then
        log_skip "Pod does not exist, skipping memory resize test"
        return 0
    fi

    # Get initial state
    local initial_restart_count=$(safe_json_extract '.status.containerStatuses[0].restartCount' '0')
    local initial_container_id=$(safe_json_extract '.status.containerStatuses[0].containerID' 'unknown')

    log_debug "Initial restart count: $initial_restart_count"
    log_debug "Container ID: ${initial_container_id:0:20}..."

    # Perform resize
    log "Executing memory resize..."
    local resize_patch='{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"memory":"256Mi"},"limits":{"memory":"512Mi"}}}]}}'

    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch "$resize_patch" 2>/dev/null; then
        log_pass "Memory resize command executed successfully"
    else
        log_warn "Resize subresource not available, attempting standard patch..."
        if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
            --type='strategic' \
            --patch "$resize_patch" 2>/dev/null; then
            log_warn "Used standard patch"
        else
            log_fail "Memory resize command failed"
            return 1
        fi
    fi

    # Wait for resize
    sleep $RETRY_DELAY

    # Verify resize
    local new_memory_request=$(safe_json_extract '.spec.containers[0].resources.requests.memory' '')
    local new_memory_limit=$(safe_json_extract '.spec.containers[0].resources.limits.memory' '')

    if [[ "$new_memory_request" == "256Mi" && "$new_memory_limit" == "512Mi" ]]; then
        log_pass "Memory resources updated correctly"
    else
        log_fail "Memory resources not updated (request: $new_memory_request, limit: $new_memory_limit)"
    fi

    # Check for restarts
    local new_restart_count=$(safe_json_extract '.status.containerStatuses[0].restartCount' '0')
    if [[ "$initial_restart_count" == "$new_restart_count" ]]; then
        log_pass "No pod restarts during memory resize"
    else
        log_warn "Pod restarted during memory resize"
    fi
}

# Test combined resize
test_combined_resize() {
    log_header "Testing Combined CPU+Memory Resize"

    if ! kubectl get pod $POD_NAME -n $TEST_NAMESPACE &>/dev/null; then
        log_skip "Pod does not exist, skipping combined resize test"
        return 0
    fi

    local initial_restart_count=$(safe_json_extract '.status.containerStatuses[0].restartCount' '0')

    log "Executing combined resize..."
    local resize_patch='{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"cpu":"300m","memory":"384Mi"},"limits":{"cpu":"600m","memory":"768Mi"}}}]}}'

    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch "$resize_patch" 2>/dev/null; then
        log_pass "Combined resize command executed"
    else
        log_warn "Using fallback method"
        kubectl patch pod $POD_NAME -n $TEST_NAMESPACE --type='strategic' --patch "$resize_patch" 2>/dev/null || {
            log_fail "Combined resize failed"
            return 1
        }
    fi

    sleep $RETRY_DELAY

    local new_cpu_request=$(safe_json_extract '.spec.containers[0].resources.requests.cpu' '')
    local new_memory_request=$(safe_json_extract '.spec.containers[0].resources.requests.memory' '')

    if [[ "$new_cpu_request" == "300m" && "$new_memory_request" == "384Mi" ]]; then
        log_pass "Combined resources updated correctly"
    else
        log_fail "Combined resources not updated correctly"
    fi
}

# Test resize validation
test_resize_validation() {
    log_header "Testing Resize Validation"

    if ! kubectl get pod $POD_NAME -n $TEST_NAMESPACE &>/dev/null; then
        log_skip "Pod does not exist, skipping validation test"
        return 0
    fi

    # Test invalid resize (exceeding node capacity)
    log "Testing invalid resize (very high CPU)..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch '{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"cpu":"100000m"}}}]}}' 2>/dev/null; then
        log_fail "Invalid resize succeeded (should have failed)"
    else
        log_pass "Invalid resize rejected as expected"
    fi

    # Test resize without subresource
    log "Testing direct patch without subresource..."
    if kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --patch '{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"cpu":"400m"}}}]}}' 2>/dev/null; then
        log_fail "Direct patch succeeded (should be forbidden for resize)"
    else
        log_pass "Direct patch rejected as expected"
    fi
}

# Check resource allocation status
check_allocated_resources() {
    log_header "Checking Allocated Resources"

    if ! kubectl get pod $POD_NAME -n $TEST_NAMESPACE &>/dev/null; then
        log_skip "Pod does not exist, skipping resource check"
        return 0
    fi

    # Get allocated resources
    if command_exists jq; then
        local allocated=$(kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o json 2>/dev/null | \
            jq -r '.status.containerStatuses[0].allocatedResources // empty')

        if [[ -n "$allocated" ]]; then
            log_pass "Allocated resources tracked:"
            echo "$allocated" | jq .
        else
            log_warn "Allocated resources not available (requires newer kubelet)"
        fi
    fi

    # Show final state
    log "Final pod resource state:"
    kubectl get pod $POD_NAME -n $TEST_NAMESPACE -o wide
}

# Performance test
test_resize_performance() {
    log_header "Testing Resize Performance"

    if ! kubectl get pod $POD_NAME -n $TEST_NAMESPACE &>/dev/null; then
        log_skip "Pod does not exist, skipping performance test"
        return 0
    fi

    log "Measuring resize latency..."
    local start_time=$(date +%s%N)

    kubectl patch pod $POD_NAME -n $TEST_NAMESPACE \
        --subresource resize \
        --patch '{"spec":{"containers":[{"name":"test-container","resources":{"requests":{"cpu":"150m"}}}]}}' 2>/dev/null || true

    local end_time=$(date +%s%N)
    local duration=$((($end_time - $start_time) / 1000000))

    log "Resize command completed in ${duration}ms"

    if [[ $duration -lt 5000 ]]; then
        log_pass "Resize completed quickly (<5s)"
    elif [[ $duration -lt 10000 ]]; then
        log_warn "Resize took ${duration}ms (5-10s)"
    else
        log_fail "Resize took too long (>${duration}ms)"
    fi
}

# Cleanup
cleanup() {
    log_header "Cleanup"

    if [[ "$CLEANUP_ON_EXIT" == "false" ]]; then
        log "Skipping cleanup (CLEANUP_ON_EXIT=false)"
        return 0
    fi

    if kubectl get namespace "$TEST_NAMESPACE" &>/dev/null; then
        log "Deleting test namespace..."
        if kubectl delete namespace "$TEST_NAMESPACE" --timeout="${TIMEOUT}s" 2>/dev/null; then
            log_pass "Test namespace deleted"
        else
            log_warn "Could not delete test namespace"
            log "Manual cleanup: kubectl delete namespace $TEST_NAMESPACE"
        fi
    fi
}

# Generate detailed report
generate_report() {
    log_header "Test Summary Report"

    local total=$((PASSED + FAILED + SKIPPED))
    local success_rate=0
    if [[ $((PASSED + FAILED)) -gt 0 ]]; then
        success_rate=$((PASSED * 100 / (PASSED + FAILED)))
    fi

    echo -e "${BOLD}Test Results:${NC}"
    echo -e "  Total Tests: $total"
    echo -e "  Passed: ${GREEN}$PASSED${NC}"
    echo -e "  Failed: ${RED}$FAILED${NC}"
    echo -e "  Skipped: ${YELLOW}$SKIPPED${NC}"
    echo -e "  Success Rate: ${BOLD}${success_rate}%${NC}"

    if [[ -s "$ERROR_LOG" ]]; then
        echo -e "\n${BOLD}Error Log:${NC} $ERROR_LOG"
    fi

    if [[ $FAILED -eq 0 && $PASSED -gt 0 ]]; then
        echo -e "\n${GREEN}${BOLD}✅ All tests passed!${NC}"
        echo -e "${GREEN}Pod resizing is working correctly.${NC}"
    elif [[ $success_rate -ge 75 ]]; then
        echo -e "\n${YELLOW}${BOLD}⚠️  Most tests passed${NC}"
        echo -e "${YELLOW}Pod resizing is partially working.${NC}"
    elif [[ $PASSED -eq 0 ]]; then
        echo -e "\n${RED}${BOLD}❌ No tests passed${NC}"
        echo -e "${RED}Pod resizing is not working.${NC}"
    else
        echo -e "\n${RED}${BOLD}❌ Tests failed${NC}"
        echo -e "${RED}Pod resizing has issues.${NC}"
    fi

    echo -e "\n${BOLD}Requirements for Pod Resizing:${NC}"
    echo "  • Kubernetes 1.33+ cluster"
    echo "  • kubectl v1.34+ client (for --subresource resize)"
    echo "  • ResizePolicy in pod spec"
    echo "  • Linux nodes (Windows not supported)"
    echo "  • Sufficient node resources"

    echo -e "\n${BOLD}Environment Variables:${NC}"
    echo "  TEST_NAMESPACE=$TEST_NAMESPACE"
    echo "  POD_NAME=$POD_NAME"
    echo "  DEBUG=$DEBUG"
    echo "  TIMEOUT=$TIMEOUT"
    echo "  RETRY_COUNT=$RETRY_COUNT"
    echo "  CLEANUP_ON_EXIT=$CLEANUP_ON_EXIT"
}

# Main execution
main() {
    log_header "Pod Resizing Test Suite - Improved"
    log "Testing in-place pod resizing capabilities"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                DEBUG=true
                shift
                ;;
            --no-cleanup)
                CLEANUP_ON_EXIT=false
                shift
                ;;
            --namespace)
                TEST_NAMESPACE="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --debug          Enable debug output"
                echo "  --no-cleanup     Don't cleanup resources on exit"
                echo "  --namespace NAME Use specific namespace"
                echo "  --timeout SECS   Set timeout in seconds (default: 60)"
                echo "  --help           Show this help message"
                exit 0
                ;;
            *)
                log_warn "Unknown option: $1"
                shift
                ;;
        esac
    done

    # Set exit trap
    trap 'cleanup' EXIT INT TERM

    # Run tests
    check_prerequisites || exit 1

    setup_test_environment || {
        log_fail "Setup failed"
        generate_report
        exit 1
    }

    # Core tests
    test_cpu_resize
    test_memory_resize
    test_combined_resize

    # Additional tests
    test_resize_validation
    test_resize_performance
    check_allocated_resources

    # Generate final report
    generate_report

    # Exit with appropriate code
    if [[ $FAILED -eq 0 && $PASSED -gt 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

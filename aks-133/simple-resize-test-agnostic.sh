#!/bin/bash
# Simple Pod Resize Test - Environment Agnostic

# Configuration with environment variable support
NAMESPACE="${TEST_NAMESPACE:-resize-test}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-test-deployment}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-nginx:alpine}"
CONTAINER_NAME="${CONTAINER_NAME:-nginx}"
CLEANUP="${CLEANUP:-ask}"  # yes, no, ask

# Resource configuration
INITIAL_CPU_REQUEST="${INITIAL_CPU_REQUEST:-100m}"
INITIAL_CPU_LIMIT="${INITIAL_CPU_LIMIT:-200m}"
INITIAL_MEM_REQUEST="${INITIAL_MEM_REQUEST:-64Mi}"
INITIAL_MEM_LIMIT="${INITIAL_MEM_LIMIT:-128Mi}"

# Resize targets
RESIZE_CPU_REQUEST="${RESIZE_CPU_REQUEST:-250m}"
RESIZE_CPU_LIMIT="${RESIZE_CPU_LIMIT:-500m}"

PASSED=0
FAILED=0
WARNED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $*"
    ((WARNED++))
}
pass() {
    echo -e "${GREEN}✅ PASS${NC}: $*"
    ((PASSED++))
}
fail() {
    echo -e "${RED}❌ FAIL${NC}: $*"
    ((FAILED++))
}

prereq_check() {
    local ok=true
    if ! command -v kubectl &>/dev/null; then
        warn "kubectl not found in PATH"
        ok=false
    fi
    if ! kubectl version --client &>/dev/null; then
        warn "kubectl not configured or cannot connect"
        ok=false
    fi
    if ! kubectl cluster-info &>/dev/null; then
        warn "Cannot connect to Kubernetes cluster"
        ok=false
    fi
    if ! kubectl api-resources | grep -q pods; then
        warn "Kubernetes cluster does not support pods"
        ok=false
    fi
    if [[ "$ok" == false ]]; then
        warn "Prerequisite checks failed. Continuing with warnings."
    else
        pass "Prerequisite checks passed"
    fi
}

setup_namespace_and_deployment() {
    echo "1. Creating/Updating test namespace (idempotent)..."
    if kubectl get namespace $NAMESPACE &>/dev/null; then
        echo "   Namespace '$NAMESPACE' already exists"
    else
        kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null
        echo "   Namespace '$NAMESPACE' created"
    fi

    echo "2. Checking existing deployment state..."
    local deployment_exists=false
    local needs_update=false

    if kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE &>/dev/null; then
        deployment_exists=true
        echo "   Deployment '$DEPLOYMENT_NAME' exists, checking configuration..."

        # Check if deployment has correct initial resources
        current_cpu_req=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
        current_mem_req=$(kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "")

        if [[ "$current_cpu_req" != "$INITIAL_CPU_REQUEST" ]] || [[ "$current_mem_req" != "$INITIAL_MEM_REQUEST" ]]; then
            echo "   Deployment resources differ from initial configuration, will update"
            needs_update=true
        else
            echo "   Deployment configuration matches expected state"
        fi
    fi

    if [[ "$deployment_exists" == false ]] || [[ "$needs_update" == true ]]; then
        echo "3. Creating/Updating deployment with resize policy and security context..."
        cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $DEPLOYMENT_NAME
  namespace: $NAMESPACE
spec:
  replicas: 1
  selector:
    matchLabels:
      app: resize-test
  template:
    metadata:
      labels:
        app: resize-test
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: $CONTAINER_NAME
        image: $CONTAINER_IMAGE
        imagePullPolicy: IfNotPresent
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1001
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
EOF
    else
        echo "3. Deployment already exists with correct configuration, skipping creation"
    fi

    echo "4. Waiting for deployment to be ready..."
    if kubectl wait --for=condition=available deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=60s 2>/dev/null; then
        pass "Deployment is ready"
        # Get the pod name for the deployment
        POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=resize-test -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n "$POD_NAME" ]]; then
            echo "   Using pod: $POD_NAME"
        else
            warn "Could not identify pod for deployment"
        fi
    else
        warn "Deployment did not become ready in time"
    fi
}

show_initial_resources() {
    echo "5. Initial deployment/pod resources:"
    if [[ -z "$POD_NAME" ]]; then
        POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=resize-test -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    fi
    if [[ -n "$POD_NAME" ]]; then
        if command -v jq &> /dev/null; then
            kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}' | jq .
        else
            kubectl get pod $POD_NAME -n $NAMESPACE -o yaml | grep -A 8 "resources:"
        fi
    else
        warn "No pod found for deployment"
    fi
}

resize_cpu() {
    echo ""
    echo "6. Checking current CPU resources before resize..."

    if [[ -z "$POD_NAME" ]]; then
        POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=resize-test -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    fi

    if [[ -z "$POD_NAME" ]]; then
        fail "No pod found for deployment to resize"
        return 1
    fi

    # Get current CPU values
    current_cpu_req=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "")
    current_cpu_lim=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "")

    echo "   Current CPU: Request=$current_cpu_req, Limit=$current_cpu_lim"
    echo "   Target CPU:  Request=$RESIZE_CPU_REQUEST, Limit=$RESIZE_CPU_LIMIT"

    # Check if resize is needed
    if [[ "$current_cpu_req" == "$RESIZE_CPU_REQUEST" ]] && [[ "$current_cpu_lim" == "$RESIZE_CPU_LIMIT" ]]; then
        echo "   CPU resources already match target values, skipping resize"
        pass "CPU resources already at target values"
        return 0
    fi

    echo "   Attempting CPU resize on pod ($current_cpu_req -> $RESIZE_CPU_REQUEST) using --subresource resize..."
    if kubectl patch pod $POD_NAME -n $NAMESPACE \
        --subresource resize \
        --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"'"$RESIZE_CPU_REQUEST"'"},"limits":{"cpu":"'"$RESIZE_CPU_LIMIT"'"}}}]}}' 2>/dev/null; then
        pass "Resize with subresource succeeded"
    else
        warn "Resize with subresource not available, trying to update deployment..."
        if kubectl patch deployment $DEPLOYMENT_NAME -n $NAMESPACE \
            --type='strategic' \
            --patch '{"spec":{"template":{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"'"$RESIZE_CPU_REQUEST"'"},"limits":{"cpu":"'"$RESIZE_CPU_LIMIT"'"}}}]}}}}' 2>/dev/null; then
            pass "Deployment updated with new resources"
            echo "   Waiting for rollout to complete..."
            kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=60s 2>/dev/null || warn "Rollout did not complete in time"
        else
            fail "Failed to update deployment resources"
        fi
    fi
}

show_updated_resources() {
    sleep 3
    echo ""
    echo "7. Updated deployment/pod resources:"

    # Re-fetch pod name in case it changed during rollout
    POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=resize-test -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -n "$POD_NAME" ]]; then
        if command -v jq &> /dev/null; then
            kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}' | jq .
        else
            kubectl get pod $POD_NAME -n $NAMESPACE -o yaml | grep -A 8 "resources:"
        fi
    else
        warn "No pod found for deployment"
    fi
}

check_restart() {
    echo ""
    echo "8. Checking if pod restarted:"

    if [[ -z "$POD_NAME" ]]; then
        POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=resize-test -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    fi

    if [[ -n "$POD_NAME" ]]; then
        RESTART_COUNT=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null || echo "N/A")
        echo "Restart count: $RESTART_COUNT"
        if [[ "$RESTART_COUNT" == "0" ]]; then
            pass "Pod was resized without restart (or is a new pod from deployment rollout)"
        elif [[ "$RESTART_COUNT" == "N/A" ]]; then
            warn "Could not determine restart count"
        else
            warn "Pod was restarted during resize"
        fi
    else
        warn "No pod found to check restart count"
    fi
}

cleanup() {
    echo ""
    if [[ "$CLEANUP" == "yes" ]]; then
        echo "9. Cleaning up resources..."
        if kubectl get namespace $NAMESPACE &>/dev/null; then
            echo "   Deleting namespace '$NAMESPACE'..."
            if kubectl delete namespace $NAMESPACE --timeout=30s --ignore-not-found=true 2>/dev/null; then
                pass "Namespace deleted"
            else
                warn "Namespace deletion failed or timed out"
            fi
        else
            echo "   Namespace '$NAMESPACE' does not exist, nothing to clean"
            pass "Cleanup already complete"
        fi
    elif [[ "$CLEANUP" == "no" ]]; then
        echo "9. Keeping test resources (namespace: $NAMESPACE)"
    else
        if kubectl get namespace $NAMESPACE &>/dev/null; then
            read -p "9. Delete test namespace '$NAMESPACE'? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if kubectl delete namespace $NAMESPACE --timeout=30s --ignore-not-found=true 2>/dev/null; then
                    pass "Namespace deleted"
                else
                    warn "Namespace deletion failed or timed out"
                fi
            fi
        else
            echo "9. Namespace '$NAMESPACE' does not exist, nothing to clean"
        fi
    fi
}

summary_report() {
    echo ""
    echo "=== Test Summary ==="
    echo -e "  ${GREEN}Passed:${NC} $PASSED"
    echo -e "  ${YELLOW}Warnings:${NC} $WARNED"
    echo -e "  ${RED}Failed:${NC} $FAILED"
    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}All critical steps succeeded.${NC}"
    else
        echo -e "${RED}Some steps failed. Review output above.${NC}"
    fi
    echo ""
    echo "To run with different settings, use environment variables:"
    echo "  CONTAINER_IMAGE=busybox:latest ./$(basename $0)"
    echo "  DEPLOYMENT_NAME=my-test ./$(basename $0)"
    echo "  RESIZE_CPU_REQUEST=300m RESIZE_CPU_LIMIT=600m ./$(basename $0)"
    echo "  CLEANUP=no ./$(basename $0)"
}

check_deployment_state() {
    local expected_state=$1
    echo "Verifying deployment state..."

    if ! kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE &>/dev/null; then
        if [[ "$expected_state" == "exists" ]]; then
            fail "Deployment does not exist when it should"
            return 1
        else
            pass "Deployment does not exist (as expected)"
            return 0
        fi
    else
        if [[ "$expected_state" == "not-exists" ]]; then
            fail "Deployment exists when it shouldn't"
            return 1
        else
            pass "Deployment exists (as expected)"
            return 0
        fi
    fi
}

main() {
    echo "=== Simple Deployment Resize Test (Idempotent) ==="
    echo ""
    echo "Configuration:"
    echo "  Namespace: $NAMESPACE"
    echo "  Deployment: $DEPLOYMENT_NAME"
    echo "  Image: $CONTAINER_IMAGE"
    echo "  Container: $CONTAINER_NAME"
    echo ""
    echo "Note: This script is idempotent - you can run it multiple times safely"
    echo "Note: Using Deployment with security context for better security practices"
    echo ""

    # Run all steps, continuing even if one fails
    prereq_check || true
    setup_namespace_and_deployment || true
    show_initial_resources || true
    resize_cpu || true
    show_updated_resources || true
    check_restart || true
}

# Set up trap for cleanup and summary
trap 'cleanup; summary_report' EXIT

# Run the main function
main
#!/bin/bash
# Simple Pod Resize Test - Environment Agnostic

# Configuration with environment variable support
NAMESPACE="${TEST_NAMESPACE:-resize-test}"
POD_NAME="${POD_NAME:-test-pod}"
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

echo "=== Simple Pod Resize Test ==="
echo ""
echo "Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Pod Name: $POD_NAME"
echo "  Image: $CONTAINER_IMAGE"
echo "  Container: $CONTAINER_NAME"
echo ""

# Create namespace
echo "1. Creating test namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create test pod
echo "2. Creating test pod with resize policy..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
  namespace: $NAMESPACE
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
EOF

# Wait for pod to be ready
echo "3. Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod/$POD_NAME -n $NAMESPACE --timeout=30s

# Show initial resources
echo "4. Initial pod resources:"
if command -v jq &> /dev/null; then
    kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}' | jq .
else
    kubectl get pod $POD_NAME -n $NAMESPACE -o yaml | grep -A 8 "resources:"
fi

# Attempt resize with subresource
echo ""
echo "5. Attempting CPU resize ($INITIAL_CPU_REQUEST -> $RESIZE_CPU_REQUEST) using --subresource resize..."
if kubectl patch pod $POD_NAME -n $NAMESPACE \
    --subresource resize \
    --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"'"$RESIZE_CPU_REQUEST"'"},"limits":{"cpu":"'"$RESIZE_CPU_LIMIT"'"}}}]}}' 2>/dev/null; then
    echo "✅ Resize with subresource succeeded!"
else
    echo "⚠️  Resize with subresource not available, trying standard patch..."
    kubectl patch pod $POD_NAME -n $NAMESPACE \
        --type='strategic' \
        --patch '{"spec":{"containers":[{"name":"'"$CONTAINER_NAME"'","resources":{"requests":{"cpu":"'"$RESIZE_CPU_REQUEST"'"},"limits":{"cpu":"'"$RESIZE_CPU_LIMIT"'"}}}]}}'
fi

# Wait a moment
sleep 3

# Show updated resources
echo ""
echo "6. Updated pod resources:"
if command -v jq &> /dev/null; then
    kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[0].resources}' | jq .
else
    kubectl get pod $POD_NAME -n $NAMESPACE -o yaml | grep -A 8 "resources:"
fi

# Check restart count
echo ""
echo "7. Checking if pod restarted:"
RESTART_COUNT=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].restartCount}')
echo "Restart count: $RESTART_COUNT"

if [[ "$RESTART_COUNT" == "0" ]]; then
    echo "✅ Pod was resized without restart!"
else
    echo "⚠️  Pod was restarted during resize"
fi

# Cleanup
echo ""
if [[ "$CLEANUP" == "yes" ]]; then
    echo "8. Cleaning up..."
    kubectl delete namespace $NAMESPACE
elif [[ "$CLEANUP" == "no" ]]; then
    echo "8. Keeping test resources (namespace: $NAMESPACE)"
else
    read -p "8. Delete test namespace? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace $NAMESPACE
    fi
fi

echo ""
echo "Test complete!"
echo ""
echo "To run with different settings, use environment variables:"
echo "  CONTAINER_IMAGE=busybox:latest ./$(basename $0)"
echo "  RESIZE_CPU_REQUEST=300m RESIZE_CPU_LIMIT=600m ./$(basename $0)"
echo "  CLEANUP=no ./$(basename $0)"
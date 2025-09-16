#!/bin/bash
# Simple Pod Resize Test

echo "=== Simple Pod Resize Test ==="
echo ""

# Create namespace
echo "1. Creating test namespace..."
kubectl create namespace resize-test --dry-run=client -o yaml | kubectl apply -f -

# Create test pod
echo "2. Creating test pod with resize policy..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: resize-test
spec:
  containers:
  - name: nginx
    image: nginx:alpine
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
EOF

# Wait for pod to be ready
echo "3. Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod/test-pod -n resize-test --timeout=30s

# Show initial resources
echo "4. Initial pod resources:"
kubectl get pod test-pod -n resize-test -o jsonpath='{.spec.containers[0].resources}' | jq . || \
kubectl get pod test-pod -n resize-test -o yaml | grep -A 8 "resources:"

# Attempt resize with subresource
echo ""
echo "5. Attempting CPU resize (100m -> 250m) using --subresource resize..."
if kubectl patch pod test-pod -n resize-test \
    --subresource resize \
    --patch '{"spec":{"containers":[{"name":"nginx","resources":{"requests":{"cpu":"250m"},"limits":{"cpu":"500m"}}}]}}' 2>/dev/null; then
    echo "✅ Resize with subresource succeeded!"
else
    echo "⚠️  Resize with subresource not available, trying standard patch..."
    kubectl patch pod test-pod -n resize-test \
        --type='strategic' \
        --patch '{"spec":{"containers":[{"name":"nginx","resources":{"requests":{"cpu":"250m"},"limits":{"cpu":"500m"}}}]}}'
fi

# Wait a moment
sleep 3

# Show updated resources
echo ""
echo "6. Updated pod resources:"
kubectl get pod test-pod -n resize-test -o jsonpath='{.spec.containers[0].resources}' | jq . || \
kubectl get pod test-pod -n resize-test -o yaml | grep -A 8 "resources:"

# Check restart count
echo ""
echo "7. Checking if pod restarted:"
RESTART_COUNT=$(kubectl get pod test-pod -n resize-test -o jsonpath='{.status.containerStatuses[0].restartCount}')
echo "Restart count: $RESTART_COUNT"

if [[ "$RESTART_COUNT" == "0" ]]; then
    echo "✅ Pod was resized without restart!"
else
    echo "⚠️  Pod was restarted during resize"
fi

# Cleanup
echo ""
read -p "8. Delete test namespace? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete namespace resize-test
fi

echo ""
echo "Test complete!"
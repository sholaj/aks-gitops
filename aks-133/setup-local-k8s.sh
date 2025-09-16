#!/bin/bash
# Local Kubernetes Setup Script for Pod Resize Testing
# Supports kind, minikube, and Docker Desktop

set -euo pipefail

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-pod-resize-test}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
K8S_PROVIDER="${K8S_PROVIDER:-auto}"  # auto, kind, minikube, docker-desktop
NODE_COUNT="${NODE_COUNT:-1}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[K8S-SETUP]${NC} $(date '+%H:%M:%S') $*"
}

log_success() {
    echo -e "${GREEN}✅${NC} $*"
}

log_error() {
    echo -e "${RED}❌${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠️${NC} $*"
}

log_header() {
    echo -e "\n${BOLD}${BLUE}=== $* ===${NC}\n"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect available Kubernetes provider
detect_provider() {
    if [[ "$K8S_PROVIDER" != "auto" ]]; then
        echo "$K8S_PROVIDER"
        return
    fi

    if command_exists kind; then
        echo "kind"
    elif command_exists minikube; then
        echo "minikube"
    elif command_exists docker && docker version &>/dev/null; then
        echo "docker-desktop"
    else
        echo "none"
    fi
}

# Install kind if not present
install_kind() {
    log_header "Installing kind"

    if command_exists kind; then
        log_success "kind is already installed ($(kind version))"
        return 0
    fi

    log "Installing kind..."

    # Detect OS
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"

    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac

    # Install based on OS
    case "$OS" in
        darwin)
            if command_exists brew; then
                brew install kind
            else
                curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-$ARCH"
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            fi
            ;;
        linux)
            curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-$ARCH"
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
            ;;
        *)
            log_error "Unsupported OS: $OS"
            return 1
            ;;
    esac

    if command_exists kind; then
        log_success "kind installed successfully"
    else
        log_error "Failed to install kind"
        return 1
    fi
}

# Install minikube if not present
install_minikube() {
    log_header "Installing minikube"

    if command_exists minikube; then
        log_success "minikube is already installed ($(minikube version --short))"
        return 0
    fi

    log "Installing minikube..."

    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"

    case "$OS" in
        darwin)
            if command_exists brew; then
                brew install minikube
            else
                curl -LO "https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-$ARCH"
                sudo install "minikube-darwin-$ARCH" /usr/local/bin/minikube
                rm "minikube-darwin-$ARCH"
            fi
            ;;
        linux)
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm minikube-linux-amd64
            ;;
        *)
            log_error "Unsupported OS: $OS"
            return 1
            ;;
    esac

    if command_exists minikube; then
        log_success "minikube installed successfully"
    else
        log_error "Failed to install minikube"
        return 1
    fi
}

# Create kind cluster
create_kind_cluster() {
    log_header "Creating kind cluster"

    # Check if cluster exists
    if kind get clusters 2>/dev/null | grep -q "^$CLUSTER_NAME$"; then
        log_warn "Cluster '$CLUSTER_NAME' already exists"
        read -p "Delete and recreate? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kind delete cluster --name "$CLUSTER_NAME"
        else
            log "Using existing cluster"
            return 0
        fi
    fi

    # Create kind config
    cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $CLUSTER_NAME
nodes:
- role: control-plane
  image: kindest/node:$K8S_VERSION
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        feature-gates: "InPlacePodVerticalScaling=true"
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        feature-gates: "InPlacePodVerticalScaling=true"
    controllerManager:
      extraArgs:
        feature-gates: "InPlacePodVerticalScaling=true"
    scheduler:
      extraArgs:
        feature-gates: "InPlacePodVerticalScaling=true"
EOF

    # Add worker nodes if requested
    if [[ $NODE_COUNT -gt 1 ]]; then
        for ((i=1; i<$NODE_COUNT; i++)); do
            cat >> /tmp/kind-config.yaml <<EOF
- role: worker
  image: kindest/node:$K8S_VERSION
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        feature-gates: "InPlacePodVerticalScaling=true"
EOF
        done
    fi

    # Create cluster
    log "Creating kind cluster with Kubernetes $K8S_VERSION..."
    if kind create cluster --config /tmp/kind-config.yaml; then
        log_success "kind cluster created successfully"
        kubectl cluster-info --context "kind-$CLUSTER_NAME"
    else
        log_error "Failed to create kind cluster"
        return 1
    fi
}

# Create minikube cluster
create_minikube_cluster() {
    log_header "Creating minikube cluster"

    # Check if cluster exists
    if minikube status -p "$CLUSTER_NAME" &>/dev/null; then
        log_warn "Cluster '$CLUSTER_NAME' already exists"
        read -p "Delete and recreate? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            minikube delete -p "$CLUSTER_NAME"
        else
            log "Using existing cluster"
            minikube start -p "$CLUSTER_NAME"
            return 0
        fi
    fi

    # Detect driver
    local driver="docker"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if command_exists hyperkit; then
            driver="hyperkit"
        elif command_exists virtualbox; then
            driver="virtualbox"
        fi
    fi

    log "Creating minikube cluster with Kubernetes $K8S_VERSION..."
    if minikube start \
        -p "$CLUSTER_NAME" \
        --kubernetes-version="$K8S_VERSION" \
        --nodes="$NODE_COUNT" \
        --driver="$driver" \
        --feature-gates="InPlacePodVerticalScaling=true" \
        --extra-config=kubelet.feature-gates="InPlacePodVerticalScaling=true"; then
        log_success "minikube cluster created successfully"
        kubectl cluster-info
    else
        log_error "Failed to create minikube cluster"
        return 1
    fi
}

# Setup Docker Desktop Kubernetes
setup_docker_desktop() {
    log_header "Setting up Docker Desktop Kubernetes"

    if ! command_exists docker; then
        log_error "Docker is not installed"
        log "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop"
        return 1
    fi

    if ! docker version &>/dev/null; then
        log_error "Docker daemon is not running"
        log "Please start Docker Desktop"
        return 1
    fi

    # Check if Kubernetes is enabled
    if kubectl config get-contexts | grep -q "docker-desktop"; then
        log_success "Docker Desktop Kubernetes is available"
        kubectl config use-context docker-desktop
        kubectl cluster-info
    else
        log_error "Kubernetes is not enabled in Docker Desktop"
        log "Please enable Kubernetes in Docker Desktop settings"
        return 1
    fi
}

# Install kubectl if not present
install_kubectl() {
    log_header "Checking kubectl"

    if command_exists kubectl; then
        local version=$(kubectl version --client --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        log_success "kubectl is installed ($version)"

        # Check if version supports resize subresource
        if [[ "$version" != "unknown" ]]; then
            local minor_version=$(echo "$version" | cut -d. -f2)
            if [[ "$minor_version" -lt 34 ]]; then
                log_warn "kubectl $version may not support --subresource resize flag"
                log "Consider upgrading to kubectl v1.34+"
            fi
        fi
        return 0
    fi

    log "Installing kubectl..."

    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"

    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac

    case "$OS" in
        darwin)
            if command_exists brew; then
                brew install kubectl
            else
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/$ARCH/kubectl"
                chmod +x ./kubectl
                sudo mv ./kubectl /usr/local/bin/kubectl
            fi
            ;;
        linux)
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/$ARCH/kubectl"
            chmod +x ./kubectl
            sudo mv ./kubectl /usr/local/bin/kubectl
            ;;
        *)
            log_error "Unsupported OS: $OS"
            return 1
            ;;
    esac

    if command_exists kubectl; then
        log_success "kubectl installed successfully"
    else
        log_error "Failed to install kubectl"
        return 1
    fi
}

# Verify cluster setup
verify_cluster() {
    log_header "Verifying Cluster Setup"

    # Check connectivity
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to cluster"
        return 1
    fi

    # Get cluster version
    local cluster_version=$(kubectl version --short 2>/dev/null | grep "Server" | grep -oE 'v[0-9]+\.[0-9]+' || echo "unknown")
    log "Cluster version: $cluster_version"

    # Check nodes
    log "Cluster nodes:"
    kubectl get nodes

    # Check if pod resizing is supported
    local minor_version=$(echo "$cluster_version" | cut -d. -f2)
    if [[ "$minor_version" -ge 33 ]]; then
        log_success "Cluster supports pod resizing (v1.33+)"
    else
        log_warn "Cluster version $cluster_version may not fully support pod resizing"
        log "Pod resizing requires Kubernetes v1.33+"
    fi

    # Create test namespace
    kubectl create namespace test-resize --dry-run=client -o yaml | kubectl apply -f - &>/dev/null
    log_success "Test namespace created"

    # Test pod creation
    kubectl run test-pod --image=nginx:alpine -n test-resize --restart=Never &>/dev/null || true
    if kubectl wait --for=condition=ready pod/test-pod -n test-resize --timeout=30s &>/dev/null; then
        log_success "Test pod running successfully"
        kubectl delete pod test-pod -n test-resize &>/dev/null
    else
        log_warn "Test pod failed to start"
    fi

    kubectl delete namespace test-resize &>/dev/null || true

    log_success "Cluster verification complete"
}

# Run the pod resize tests
run_tests() {
    log_header "Running Pod Resize Tests"

    local test_script="./test-pod-resize-improved.sh"

    if [[ ! -f "$test_script" ]]; then
        test_script="./test-pod-resize-v2.sh"
    fi

    if [[ ! -f "$test_script" ]]; then
        log_error "Test script not found"
        log "Expected: test-pod-resize-improved.sh or test-pod-resize-v2.sh"
        return 1
    fi

    log "Running test script: $test_script"
    chmod +x "$test_script"

    if bash "$test_script"; then
        log_success "Tests completed successfully"
    else
        log_error "Tests failed"
        return 1
    fi
}

# Cleanup
cleanup_cluster() {
    log_header "Cleanup"

    read -p "Delete the test cluster? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Keeping cluster for further testing"
        return 0
    fi

    case "$provider" in
        kind)
            kind delete cluster --name "$CLUSTER_NAME"
            log_success "kind cluster deleted"
            ;;
        minikube)
            minikube delete -p "$CLUSTER_NAME"
            log_success "minikube cluster deleted"
            ;;
        docker-desktop)
            log "Docker Desktop cluster remains available"
            ;;
        *)
            log_warn "Unknown provider, manual cleanup may be needed"
            ;;
    esac
}

# Print usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Setup local Kubernetes cluster for pod resize testing

Options:
    --provider PROVIDER   Kubernetes provider (auto, kind, minikube, docker-desktop)
    --cluster-name NAME   Cluster name (default: pod-resize-test)
    --k8s-version VERSION Kubernetes version (default: v1.33.0)
    --nodes COUNT         Number of nodes (default: 1)
    --run-tests           Run tests after setup
    --cleanup             Cleanup cluster after tests
    --help                Show this help message

Examples:
    # Auto-detect and use available provider
    $0

    # Use specific provider
    $0 --provider kind

    # Create multi-node cluster and run tests
    $0 --provider kind --nodes 3 --run-tests

    # Use specific Kubernetes version
    $0 --k8s-version v1.34.0

EOF
}

# Main function
main() {
    local provider=""
    local run_tests_flag=false
    local cleanup_flag=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --provider)
                K8S_PROVIDER="$2"
                shift 2
                ;;
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --k8s-version)
                K8S_VERSION="$2"
                shift 2
                ;;
            --nodes)
                NODE_COUNT="$2"
                shift 2
                ;;
            --run-tests)
                run_tests_flag=true
                shift
                ;;
            --cleanup)
                cleanup_flag=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    log_header "Local Kubernetes Setup for Pod Resize Testing"

    # Install kubectl first
    install_kubectl || exit 1

    # Detect provider
    provider=$(detect_provider)
    log "Selected provider: $provider"

    case "$provider" in
        kind)
            install_kind || exit 1
            create_kind_cluster || exit 1
            ;;
        minikube)
            install_minikube || exit 1
            create_minikube_cluster || exit 1
            ;;
        docker-desktop)
            setup_docker_desktop || exit 1
            ;;
        none)
            log_error "No Kubernetes provider available"
            log "Please install one of: kind, minikube, or Docker Desktop"
            log ""
            log "Quick install:"
            log "  macOS:  brew install kind"
            log "  Linux:  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
            exit 1
            ;;
        *)
            log_error "Unknown provider: $provider"
            exit 1
            ;;
    esac

    # Verify cluster
    verify_cluster || exit 1

    # Run tests if requested
    if [[ "$run_tests_flag" == "true" ]]; then
        run_tests || log_warn "Tests failed but cluster is ready"
    fi

    # Cleanup if requested
    if [[ "$cleanup_flag" == "true" ]]; then
        cleanup_cluster
    fi

    log_success "Setup complete!"
    log ""
    log "Next steps:"
    log "  1. Run tests: ./test-pod-resize-improved.sh"
    log "  2. Check cluster: kubectl get nodes"
    log "  3. View context: kubectl config current-context"

    if [[ "$provider" == "kind" ]]; then
        log "  4. Delete cluster: kind delete cluster --name $CLUSTER_NAME"
    elif [[ "$provider" == "minikube" ]]; then
        log "  4. Delete cluster: minikube delete -p $CLUSTER_NAME"
    fi
}

# Execute main function
main "$@"
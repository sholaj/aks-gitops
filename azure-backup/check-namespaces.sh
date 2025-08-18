#!/bin/bash

# Namespace Identification Utility for AKS Backup
# This script identifies and lists namespaces matching the ATXXXX pattern

set -e

# Configuration
SUBSCRIPTION_ID="469b61e7-a78a-4d21-b39e-3b130e4b8e2b"
RESOURCE_GROUP="AT39473-weu-dev-d01"
AKS_CLUSTER_NAME="uk8s-tsshared-weu-gt025-int-d01"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_header() {
    echo -e "${BLUE}$1${NC}"
}

# Function to connect to AKS
connect_to_aks() {
    log_info "Connecting to AKS cluster: ${AKS_CLUSTER_NAME}..."
    
    # Set subscription
    az account set --subscription "${SUBSCRIPTION_ID}"
    
    # Get AKS credentials
    az aks get-credentials \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${AKS_CLUSTER_NAME}" \
        --overwrite-existing &>/dev/null
    
    # Convert kubeconfig for Azure AD
    kubelogin convert-kubeconfig -l azurecli &>/dev/null
    
    log_info "Successfully connected to AKS cluster."
}

# Function to get all namespaces
get_all_namespaces() {
    kubectl get namespaces -o json | jq -r '.items[].metadata.name' | sort
}

# Function to get namespaces matching ATXXXX pattern
get_at_namespaces() {
    kubectl get namespaces -o json | jq -r '.items[].metadata.name | select(test("^AT[0-9]{4,}"))' | sort
}

# Function to analyze namespace resources
analyze_namespace() {
    local namespace=$1
    
    echo ""
    log_header "Namespace: $namespace"
    echo "----------------------------------------"
    
    # Get resource counts
    local deployments=$(kubectl get deployments -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local services=$(kubectl get services -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local pods=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local pvcs=$(kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local configmaps=$(kubectl get configmaps -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local secrets=$(kubectl get secrets -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    echo "  Deployments:    $deployments"
    echo "  Services:       $services"
    echo "  Pods:           $pods"
    echo "  PVCs:           $pvcs"
    echo "  ConfigMaps:     $configmaps"
    echo "  Secrets:        $secrets"
    
    # Get PVC details if any exist
    if [ "$pvcs" -gt 0 ]; then
        echo ""
        echo "  Persistent Volume Claims:"
        kubectl get pvc -n "$namespace" --no-headers | while read -r line; do
            pvc_name=$(echo "$line" | awk '{print $1}')
            pvc_size=$(echo "$line" | awk '{print $4}')
            pvc_status=$(echo "$line" | awk '{print $2}')
            echo "    - $pvc_name ($pvc_size, Status: $pvc_status)"
        done
    fi
    
    # Calculate approximate backup size (PVCs only)
    if [ "$pvcs" -gt 0 ]; then
        local total_size=0
        kubectl get pvc -n "$namespace" -o json | jq -r '.items[].spec.resources.requests.storage' | while read -r size; do
            # Convert to GB (rough estimate)
            size_num=$(echo "$size" | sed 's/[^0-9]//g')
            echo "    Storage: ${size}"
        done
    fi
}

# Function to generate backup configuration
generate_backup_config() {
    local namespaces=$1
    
    echo ""
    log_header "Suggested Backup Configuration:"
    echo "----------------------------------------"
    
    if [ -z "$namespaces" ]; then
        echo "No namespaces matching ATXXXX pattern found."
        echo "Recommendation: Configure backup for all namespaces or specific namespaces manually."
    else
        echo "Namespaces to include in backup:"
        echo "$namespaces" | while read -r ns; do
            echo "  - $ns"
        done
        
        echo ""
        echo "Backup configuration JSON snippet:"
        echo '{'
        echo '  "includedNamespaces": ['
        echo "$namespaces" | awk '{printf "    \"%s\"", $0}' | sed '$ ! s/$/,/'
        echo ""
        echo '  ],'
        echo '  "excludedNamespaces": [],'
        echo '  "includeClusterScopeResources": false'
        echo '}'
    fi
}

# Function to check backup readiness
check_backup_readiness() {
    echo ""
    log_header "Backup Readiness Check:"
    echo "----------------------------------------"
    
    # Check if backup extension is installed
    if kubectl get namespace dataprotection-microsoft &>/dev/null; then
        echo "✓ Backup extension namespace exists"
        
        # Check if pods are running
        local pod_count=$(kubectl get pods -n dataprotection-microsoft --no-headers 2>/dev/null | wc -l)
        if [ "$pod_count" -gt 0 ]; then
            echo "✓ Backup extension pods found ($pod_count pods)"
        else
            echo "✗ No backup extension pods found"
        fi
    else
        echo "✗ Backup extension not installed"
        echo "  Run setup-aks-backup.sh to install"
    fi
    
    # Check for CSI drivers
    if kubectl get csidrivers disk.csi.azure.com &>/dev/null; then
        echo "✓ Azure Disk CSI driver installed"
    else
        echo "✗ Azure Disk CSI driver not found"
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "================================================"
    echo "     AKS Namespace Identification Utility"
    echo "================================================"
    echo ""
    echo "1. List all namespaces"
    echo "2. List ATXXXX pattern namespaces"
    echo "3. Analyze ATXXXX namespaces (detailed)"
    echo "4. Generate backup configuration"
    echo "5. Check backup readiness"
    echo "6. Export namespace list to file"
    echo "7. Exit"
    echo ""
    read -p "Select an option (1-7): " CHOICE
    
    case $CHOICE in
        1)
            connect_to_aks
            echo ""
            log_header "All Namespaces in Cluster:"
            echo "----------------------------------------"
            get_all_namespaces
            ;;
        2)
            connect_to_aks
            echo ""
            log_header "Namespaces Matching ATXXXX Pattern:"
            echo "----------------------------------------"
            AT_NAMESPACES=$(get_at_namespaces)
            if [ -z "$AT_NAMESPACES" ]; then
                log_warning "No namespaces found matching ATXXXX pattern"
            else
                echo "$AT_NAMESPACES"
                echo ""
                echo "Total: $(echo "$AT_NAMESPACES" | wc -l) namespace(s)"
            fi
            ;;
        3)
            connect_to_aks
            echo ""
            log_header "Detailed Analysis of ATXXXX Namespaces:"
            AT_NAMESPACES=$(get_at_namespaces)
            if [ -z "$AT_NAMESPACES" ]; then
                log_warning "No namespaces found matching ATXXXX pattern"
            else
                echo "$AT_NAMESPACES" | while read -r ns; do
                    analyze_namespace "$ns"
                done
            fi
            ;;
        4)
            connect_to_aks
            AT_NAMESPACES=$(get_at_namespaces)
            generate_backup_config "$AT_NAMESPACES"
            ;;
        5)
            connect_to_aks
            check_backup_readiness
            ;;
        6)
            connect_to_aks
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            OUTPUT_FILE="namespace_list_${TIMESTAMP}.txt"
            
            echo "Namespace Report - $(date)" > "$OUTPUT_FILE"
            echo "================================" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            
            echo "All Namespaces:" >> "$OUTPUT_FILE"
            get_all_namespaces >> "$OUTPUT_FILE"
            
            echo "" >> "$OUTPUT_FILE"
            echo "ATXXXX Pattern Namespaces:" >> "$OUTPUT_FILE"
            AT_NAMESPACES=$(get_at_namespaces)
            if [ -z "$AT_NAMESPACES" ]; then
                echo "None found" >> "$OUTPUT_FILE"
            else
                echo "$AT_NAMESPACES" >> "$OUTPUT_FILE"
            fi
            
            log_info "Report saved to: $OUTPUT_FILE"
            ;;
        7)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_warning "Invalid option. Please try again."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    show_menu
}

# Main execution
main() {
    # Check prerequisites
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install it first."
        exit 1
    fi
    
    show_menu
}

# Run the script
main "$@"
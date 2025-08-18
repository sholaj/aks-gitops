#!/bin/bash

# AKS Backup Restoration Script
# This script handles restoration of AKS backups

set -e

# Configuration Variables
SUBSCRIPTION_ID="469b61e7-a78a-4d21-b39e-3b130e4b8e2b"
RESOURCE_GROUP="AT39473-weu-dev-d01"
AKS_CLUSTER_NAME="uk8s-tsshared-weu-gt025-int-d01"
BACKUP_VAULT_NAME="aks-backup-vault-${AKS_CLUSTER_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_prompt() {
    echo -e "${BLUE}[PROMPT]${NC} $1"
}

# Function to set subscription
set_subscription() {
    log_info "Setting subscription to ${SUBSCRIPTION_ID}..."
    az account set --subscription "${SUBSCRIPTION_ID}"
    log_info "Subscription set successfully."
}

# Function to list available recovery points
list_recovery_points() {
    log_info "Fetching available recovery points..."
    
    # Get backup instance name
    BACKUP_INSTANCE=$(az dataprotection backup-instance list \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --query "[0].name" -o tsv)
    
    if [ -z "$BACKUP_INSTANCE" ]; then
        log_error "No backup instances found in vault ${BACKUP_VAULT_NAME}"
        exit 1
    fi
    
    # List recovery points
    az dataprotection recovery-point list \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --backup-instance-name "${BACKUP_INSTANCE}" \
        --query "[].{Name:name,Time:properties.recoveryPointTime,Type:properties.recoveryPointType}" \
        --output table
    
    RECOVERY_POINTS=$(az dataprotection recovery-point list \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --backup-instance-name "${BACKUP_INSTANCE}" \
        --query "[].name" -o tsv)
    
    echo "$RECOVERY_POINTS"
}

# Function to select recovery point
select_recovery_point() {
    log_prompt "Available recovery points:"
    
    RECOVERY_POINTS=$(list_recovery_points)
    
    if [ -z "$RECOVERY_POINTS" ]; then
        log_error "No recovery points available for restoration."
        exit 1
    fi
    
    # Convert to array
    IFS=$'\n' read -d '' -r -a POINTS_ARRAY <<< "$RECOVERY_POINTS" || true
    
    # Display options
    echo ""
    for i in "${!POINTS_ARRAY[@]}"; do
        echo "$((i+1)). ${POINTS_ARRAY[$i]}"
    done
    
    echo ""
    read -p "Select recovery point number (1-${#POINTS_ARRAY[@]}): " SELECTION
    
    if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt "${#POINTS_ARRAY[@]}" ]; then
        log_error "Invalid selection."
        exit 1
    fi
    
    SELECTED_RECOVERY_POINT="${POINTS_ARRAY[$((SELECTION-1))]}"
    log_info "Selected recovery point: ${SELECTED_RECOVERY_POINT}"
    
    echo "$SELECTED_RECOVERY_POINT"
}

# Function to select restore type
select_restore_type() {
    log_prompt "Select restore type:"
    echo "1. Full Cluster Restore (restore all backed up resources)"
    echo "2. Namespace Restore (restore specific namespaces)"
    echo "3. Item-Level Restore (restore specific resources)"
    
    read -p "Enter choice (1-3): " RESTORE_TYPE_CHOICE
    
    case $RESTORE_TYPE_CHOICE in
        1)
            echo "FullClusterRestore"
            ;;
        2)
            echo "NamespaceRestore"
            ;;
        3)
            echo "ItemLevelRestore"
            ;;
        *)
            log_error "Invalid choice."
            exit 1
            ;;
    esac
}

# Function to get namespaces for restoration
get_restore_namespaces() {
    log_prompt "Enter namespaces to restore (comma-separated, or 'all' for all namespaces):"
    read -p "Namespaces: " NAMESPACES_INPUT
    
    if [ "$NAMESPACES_INPUT" == "all" ]; then
        echo ""
    else
        # Convert comma-separated to JSON array
        echo "$NAMESPACES_INPUT" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";""))'
    fi
}

# Function to configure restore
configure_restore() {
    local RECOVERY_POINT=$1
    local RESTORE_TYPE=$2
    
    log_info "Configuring restore operation..."
    
    # Get backup instance
    BACKUP_INSTANCE=$(az dataprotection backup-instance list \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --query "[0].name" -o tsv)
    
    # Get AKS cluster ID
    AKS_CLUSTER_ID=$(az aks show \
        --name "${AKS_CLUSTER_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query id -o tsv)
    
    # Create restore configuration based on type
    case $RESTORE_TYPE in
        "FullClusterRestore")
            RESTORE_CONFIG='{"restoreMode":"RestoreWithReplace","includedNamespaces":[],"excludedNamespaces":[]}'
            ;;
        "NamespaceRestore")
            NAMESPACES=$(get_restore_namespaces)
            if [ -z "$NAMESPACES" ]; then
                RESTORE_CONFIG='{"restoreMode":"RestoreWithReplace","includedNamespaces":[],"excludedNamespaces":[]}'
            else
                RESTORE_CONFIG="{\"restoreMode\":\"RestoreWithReplace\",\"includedNamespaces\":${NAMESPACES},\"excludedNamespaces\":[]}"
            fi
            ;;
        "ItemLevelRestore")
            log_prompt "Enter resource types to restore (comma-separated, e.g., 'deployments,services,configmaps'):"
            read -p "Resource types: " RESOURCE_TYPES
            RESOURCES_ARRAY=$(echo "$RESOURCE_TYPES" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";""))')
            
            NAMESPACES=$(get_restore_namespaces)
            if [ -z "$NAMESPACES" ]; then
                RESTORE_CONFIG="{\"restoreMode\":\"RestoreWithReplace\",\"includedNamespaces\":[],\"includedResourceTypes\":${RESOURCES_ARRAY}}"
            else
                RESTORE_CONFIG="{\"restoreMode\":\"RestoreWithReplace\",\"includedNamespaces\":${NAMESPACES},\"includedResourceTypes\":${RESOURCES_ARRAY}}"
            fi
            ;;
    esac
    
    echo "$RESTORE_CONFIG"
}

# Function to validate restore
validate_restore() {
    local RESTORE_CONFIG=$1
    
    log_info "Validating restore configuration..."
    
    # Check for existing resources that might conflict
    log_warning "Please ensure the following before proceeding:"
    echo "  1. Target namespaces are either empty or can be overwritten"
    echo "  2. No critical applications are running in target namespaces"
    echo "  3. You have taken note of current state if needed"
    
    log_prompt "Do you want to proceed with validation? (yes/no)"
    read -p "Answer: " PROCEED
    
    if [ "$PROCEED" != "yes" ]; then
        log_info "Restore cancelled by user."
        exit 0
    fi
    
    return 0
}

# Function to trigger restore
trigger_restore() {
    local RECOVERY_POINT=$1
    local RESTORE_CONFIG=$2
    
    log_info "Triggering restore operation..."
    
    # Get backup instance
    BACKUP_INSTANCE=$(az dataprotection backup-instance list \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --query "[0].name" -o tsv)
    
    # Get AKS cluster ID
    AKS_CLUSTER_ID=$(az aks show \
        --name "${AKS_CLUSTER_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query id -o tsv)
    
    # Initialize restore request
    az dataprotection restore initialize-for-data-recovery \
        --datasource-id "${AKS_CLUSTER_ID}" \
        --datasource-type "Microsoft.ContainerService/managedClusters" \
        --recovery-point-id "${RECOVERY_POINT}" \
        --restore-location "westeurope" \
        --source-datastore-type "OperationalStore" \
        --target-resource-id "${AKS_CLUSTER_ID}" \
        --restore-configuration "${RESTORE_CONFIG}" \
        > restore-request.json
    
    # Trigger the restore
    RESTORE_JOB=$(az dataprotection backup-instance restore trigger \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --backup-instance-name "${BACKUP_INSTANCE}" \
        --restore-request-object restore-request.json \
        --query "jobId" -o tsv)
    
    if [ -z "$RESTORE_JOB" ]; then
        log_error "Failed to trigger restore operation."
        exit 1
    fi
    
    log_info "Restore job initiated with ID: ${RESTORE_JOB}"
    
    # Clean up temporary file
    rm -f restore-request.json
    
    echo "$RESTORE_JOB"
}

# Function to monitor restore job
monitor_restore_job() {
    local JOB_ID=$1
    
    log_info "Monitoring restore job: ${JOB_ID}"
    log_info "This may take several minutes depending on the size of the backup..."
    
    while true; do
        JOB_STATUS=$(az dataprotection job show \
            --resource-group "${RESOURCE_GROUP}" \
            --vault-name "${BACKUP_VAULT_NAME}" \
            --job-id "${JOB_ID}" \
            --query "properties.status" -o tsv)
        
        case $JOB_STATUS in
            "Completed")
                log_info "Restore completed successfully!"
                break
                ;;
            "CompletedWithWarnings")
                log_warning "Restore completed with warnings. Please check the job details."
                break
                ;;
            "Failed")
                log_error "Restore failed. Please check the job details."
                az dataprotection job show \
                    --resource-group "${RESOURCE_GROUP}" \
                    --vault-name "${BACKUP_VAULT_NAME}" \
                    --job-id "${JOB_ID}" \
                    --query "properties.errorDetails" -o json
                exit 1
                ;;
            "InProgress"|"Started")
                echo -n "."
                sleep 30
                ;;
            *)
                log_warning "Unknown job status: ${JOB_STATUS}"
                sleep 30
                ;;
        esac
    done
    
    # Show job summary
    log_info "Restore job summary:"
    az dataprotection job show \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --job-id "${JOB_ID}" \
        --query "{Status:properties.status,StartTime:properties.startTime,EndTime:properties.endTime,Duration:properties.duration}" \
        --output table
}

# Function to verify restoration
verify_restoration() {
    log_info "Verifying restoration..."
    
    # Get AKS credentials
    az aks get-credentials \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${AKS_CLUSTER_NAME}" \
        --overwrite-existing
    
    kubelogin convert-kubeconfig -l azurecli
    
    log_info "Current namespaces in the cluster:"
    kubectl get namespaces
    
    log_prompt "Enter a namespace to check (or press Enter to skip):"
    read -p "Namespace: " CHECK_NAMESPACE
    
    if [ -n "$CHECK_NAMESPACE" ]; then
        log_info "Resources in namespace ${CHECK_NAMESPACE}:"
        kubectl get all -n "${CHECK_NAMESPACE}"
        
        log_info "Persistent Volume Claims in namespace ${CHECK_NAMESPACE}:"
        kubectl get pvc -n "${CHECK_NAMESPACE}"
    fi
}

# Function to perform ad-hoc backup
perform_adhoc_backup() {
    log_info "Triggering ad-hoc backup..."
    
    # Get backup instance
    BACKUP_INSTANCE=$(az dataprotection backup-instance list \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --query "[0].name" -o tsv)
    
    if [ -z "$BACKUP_INSTANCE" ]; then
        log_error "No backup instance found. Please run setup-aks-backup.sh first."
        exit 1
    fi
    
    # Trigger backup
    BACKUP_JOB=$(az dataprotection backup-instance adhoc-backup \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --backup-instance-name "${BACKUP_INSTANCE}" \
        --rule-name "BackupHourly" \
        --query "jobId" -o tsv)
    
    if [ -z "$BACKUP_JOB" ]; then
        log_error "Failed to trigger backup."
        exit 1
    fi
    
    log_info "Backup job initiated with ID: ${BACKUP_JOB}"
    
    # Monitor backup job
    while true; do
        JOB_STATUS=$(az dataprotection job show \
            --resource-group "${RESOURCE_GROUP}" \
            --vault-name "${BACKUP_VAULT_NAME}" \
            --job-id "${BACKUP_JOB}" \
            --query "properties.status" -o tsv)
        
        case $JOB_STATUS in
            "Completed")
                log_info "Backup completed successfully!"
                break
                ;;
            "Failed")
                log_error "Backup failed."
                exit 1
                ;;
            "InProgress"|"Started")
                echo -n "."
                sleep 30
                ;;
        esac
    done
}

# Main menu
show_menu() {
    clear
    echo "================================================"
    echo "       AKS Backup Restoration Tool"
    echo "================================================"
    echo ""
    echo "1. List available recovery points"
    echo "2. Perform full restoration"
    echo "3. Perform namespace restoration"
    echo "4. Perform item-level restoration"
    echo "5. Trigger ad-hoc backup"
    echo "6. Verify current cluster state"
    echo "7. Exit"
    echo ""
    read -p "Select an option (1-7): " CHOICE
    
    case $CHOICE in
        1)
            set_subscription
            list_recovery_points
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        2)
            set_subscription
            RECOVERY_POINT=$(select_recovery_point)
            RESTORE_CONFIG=$(configure_restore "$RECOVERY_POINT" "FullClusterRestore")
            validate_restore "$RESTORE_CONFIG"
            JOB_ID=$(trigger_restore "$RECOVERY_POINT" "$RESTORE_CONFIG")
            monitor_restore_job "$JOB_ID"
            verify_restoration
            ;;
        3)
            set_subscription
            RECOVERY_POINT=$(select_recovery_point)
            RESTORE_CONFIG=$(configure_restore "$RECOVERY_POINT" "NamespaceRestore")
            validate_restore "$RESTORE_CONFIG"
            JOB_ID=$(trigger_restore "$RECOVERY_POINT" "$RESTORE_CONFIG")
            monitor_restore_job "$JOB_ID"
            verify_restoration
            ;;
        4)
            set_subscription
            RECOVERY_POINT=$(select_recovery_point)
            RESTORE_CONFIG=$(configure_restore "$RECOVERY_POINT" "ItemLevelRestore")
            validate_restore "$RESTORE_CONFIG"
            JOB_ID=$(trigger_restore "$RECOVERY_POINT" "$RESTORE_CONFIG")
            monitor_restore_job "$JOB_ID"
            verify_restoration
            ;;
        5)
            set_subscription
            perform_adhoc_backup
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        6)
            verify_restoration
            echo ""
            read -p "Press Enter to continue..."
            show_menu
            ;;
        7)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid option."
            sleep 2
            show_menu
            ;;
    esac
}

# Main execution
main() {
    log_info "AKS Backup Restoration Tool"
    show_menu
}

# Run the script
main "$@"
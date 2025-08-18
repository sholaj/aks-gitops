#!/bin/bash

# AKS Backup Configuration Script
# This script sets up Azure Backup for AKS clusters with namespaces matching ATXXXX pattern

set -e

# Configuration Variables
SUBSCRIPTION_ID="469b61e7-a78a-4d21-b39e-3b130e4b8e2b"
RESOURCE_GROUP="AT39473-weu-dev-d01"
AKS_CLUSTER_NAME="uk8s-tsshared-weu-gt025-int-d01"
LOCATION="westeurope"
BACKUP_VAULT_NAME="aks-backup-vault-${AKS_CLUSTER_NAME}"
BACKUP_POLICY_NAME="aks-backup-policy-daily"
STORAGE_ACCOUNT_NAME="aksbackup$(date +%s)"
CONTAINER_NAME="aksbackupcontainer"
SNAPSHOT_RG_NAME="${RESOURCE_GROUP}-snapshots"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    log_info "Prerequisites check completed successfully."
}

# Function to set subscription
set_subscription() {
    log_info "Setting subscription to ${SUBSCRIPTION_ID}..."
    az account set --subscription "${SUBSCRIPTION_ID}"
    log_info "Subscription set successfully."
}

# Function to get AKS credentials
get_aks_credentials() {
    log_info "Getting AKS credentials..."
    az aks get-credentials \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${AKS_CLUSTER_NAME}" \
        --overwrite-existing
    
    # Convert kubeconfig for Azure AD authentication
    kubelogin convert-kubeconfig -l azurecli
    
    log_info "AKS credentials configured successfully."
}

# Function to create snapshot resource group
create_snapshot_resource_group() {
    log_info "Creating snapshot resource group: ${SNAPSHOT_RG_NAME}..."
    
    if az group exists --name "${SNAPSHOT_RG_NAME}" 2>/dev/null; then
        log_warning "Resource group ${SNAPSHOT_RG_NAME} already exists."
    else
        az group create \
            --name "${SNAPSHOT_RG_NAME}" \
            --location "${LOCATION}"
        log_info "Snapshot resource group created successfully."
    fi
}

# Function to create storage account for backup extension
create_storage_account() {
    log_info "Creating storage account for backup extension..."
    
    # Storage account name must be globally unique and lowercase
    STORAGE_ACCOUNT_NAME="aksbackup$(echo $RANDOM | md5sum | head -c 8)"
    
    az storage account create \
        --name "${STORAGE_ACCOUNT_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --sku Standard_LRS \
        --kind StorageV2
    
    log_info "Storage account ${STORAGE_ACCOUNT_NAME} created successfully."
    
    # Create blob container
    log_info "Creating blob container..."
    az storage container create \
        --name "${CONTAINER_NAME}" \
        --account-name "${STORAGE_ACCOUNT_NAME}" \
        --auth-mode login
    
    log_info "Blob container created successfully."
}

# Function to create backup vault
create_backup_vault() {
    log_info "Creating backup vault: ${BACKUP_VAULT_NAME}..."
    
    # Check if backup vault already exists
    if az dataprotection backup-vault show \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" &>/dev/null; then
        log_warning "Backup vault ${BACKUP_VAULT_NAME} already exists."
    else
        az dataprotection backup-vault create \
            --resource-group "${RESOURCE_GROUP}" \
            --vault-name "${BACKUP_VAULT_NAME}" \
            --location "${LOCATION}" \
            --storage-settings datastore-type="VaultStore" type="LocallyRedundant"
        
        log_info "Backup vault created successfully."
    fi
}

# Function to install backup extension on AKS
install_backup_extension() {
    log_info "Installing backup extension on AKS cluster..."
    
    # Get storage account connection details
    STORAGE_ACCOUNT_ID=$(az storage account show \
        --name "${STORAGE_ACCOUNT_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query id -o tsv)
    
    STORAGE_ACCOUNT_KEY=$(az storage account keys list \
        --account-name "${STORAGE_ACCOUNT_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query "[0].value" -o tsv)
    
    # Install the backup extension
    az k8s-extension create \
        --name azure-aks-backup \
        --extension-type microsoft.dataprotection.kubernetes \
        --scope cluster \
        --cluster-type managedClusters \
        --cluster-name "${AKS_CLUSTER_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --release-train stable \
        --configuration-settings \
            storageAccount="${STORAGE_ACCOUNT_NAME}" \
            storageAccountResourceGroup="${RESOURCE_GROUP}" \
            storageAccountContainer="${CONTAINER_NAME}" \
            storageAccountKey="${STORAGE_ACCOUNT_KEY}"
    
    log_info "Backup extension installed successfully."
}

# Function to enable trusted access
enable_trusted_access() {
    log_info "Enabling trusted access between AKS and Backup vault..."
    
    # Get AKS cluster ID
    AKS_CLUSTER_ID=$(az aks show \
        --name "${AKS_CLUSTER_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query id -o tsv)
    
    # Get Backup vault ID
    VAULT_ID=$(az dataprotection backup-vault show \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --query id -o tsv)
    
    # Enable trusted access
    az aks trustedaccess rolebinding create \
        --cluster-name "${AKS_CLUSTER_NAME}" \
        --name "backup-trusted-access" \
        --resource-group "${RESOURCE_GROUP}" \
        --roles "Microsoft.DataProtection/backupVaults/backup-operator" \
        --source-resource-id "${VAULT_ID}"
    
    log_info "Trusted access enabled successfully."
}

# Function to create backup policy
create_backup_policy() {
    log_info "Creating backup policy: ${BACKUP_POLICY_NAME}..."
    
    # Create a backup policy JSON file
    cat > backup-policy.json <<EOF
{
  "datasourceTypes": ["Microsoft.ContainerService/managedClusters"],
  "objectType": "BackupPolicy",
  "policyRules": [
    {
      "backupParameters": {
        "backupType": "Incremental",
        "objectType": "AzureBackupParams"
      },
      "dataStore": {
        "dataStoreType": "OperationalStore",
        "objectType": "DataStoreInfoBase"
      },
      "name": "BackupHourly",
      "objectType": "AzureBackupRule",
      "trigger": {
        "objectType": "ScheduleBasedTriggerContext",
        "schedule": {
          "repeatingTimeIntervals": ["R/2024-01-01T00:00:00+00:00/PT4H"],
          "timeZone": "UTC"
        },
        "taggingCriteria": [
          {
            "criteria": [
              {
                "absoluteCriteria": ["AllBackup"],
                "objectType": "ScheduleBasedBackupCriteria"
              }
            ],
            "isDefault": true,
            "tagInfo": {
              "tagName": "Default"
            },
            "taggingPriority": 99
          }
        ]
      }
    },
    {
      "lifecycles": [
        {
          "deleteAfter": {
            "duration": "P7D",
            "objectType": "AbsoluteDeleteOption"
          },
          "sourceDataStore": {
            "dataStoreType": "OperationalStore",
            "objectType": "DataStoreInfoBase"
          },
          "targetDataStoreCopySettings": []
        }
      ],
      "name": "Default",
      "objectType": "AzureRetentionRule"
    }
  ]
}
EOF
    
    # Create the backup policy
    az dataprotection backup-policy create \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --policy "${BACKUP_POLICY_NAME}" \
        --policy backup-policy.json
    
    log_info "Backup policy created successfully."
    
    # Clean up temporary file
    rm -f backup-policy.json
}

# Function to get namespaces with ATXXXX pattern
get_target_namespaces() {
    log_info "Identifying namespaces with ATXXXX pattern..."
    
    # Get all namespaces matching the pattern
    NAMESPACES=$(kubectl get namespaces -o json | jq -r '.items[].metadata.name | select(test("^AT[0-9]{4,}"))')
    
    if [ -z "$NAMESPACES" ]; then
        log_warning "No namespaces found matching ATXXXX pattern."
        log_info "Available namespaces:"
        kubectl get namespaces
        
        # For demo purposes, we'll backup all namespaces
        log_info "Configuring backup for all namespaces..."
        echo "all"
    else
        log_info "Found namespaces matching ATXXXX pattern:"
        echo "$NAMESPACES"
        echo "$NAMESPACES"
    fi
}

# Function to configure backup instance
configure_backup_instance() {
    log_info "Configuring backup instance..."
    
    # Get target namespaces
    TARGET_NAMESPACES=$(get_target_namespaces)
    
    # Get AKS cluster ID
    AKS_CLUSTER_ID=$(az aks show \
        --name "${AKS_CLUSTER_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --query id -o tsv)
    
    # Get backup policy ID
    POLICY_ID=$(az dataprotection backup-policy show \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --policy-name "${BACKUP_POLICY_NAME}" \
        --query id -o tsv)
    
    # Get snapshot resource group ID
    SNAPSHOT_RG_ID=$(az group show \
        --name "${SNAPSHOT_RG_NAME}" \
        --query id -o tsv)
    
    # Create backup instance configuration
    if [ "$TARGET_NAMESPACES" == "all" ]; then
        NAMESPACE_CONFIG='{"includedNamespaces":[],"excludedNamespaces":[],"labelSelectors":[],"includeClusterScopeResources":true}'
    else
        # Convert namespaces to JSON array
        NAMESPACE_ARRAY=$(echo "$TARGET_NAMESPACES" | jq -R -s -c 'split("\n") | map(select(length > 0))')
        NAMESPACE_CONFIG="{\"includedNamespaces\":${NAMESPACE_ARRAY},\"excludedNamespaces\":[],\"labelSelectors\":[],\"includeClusterScopeResources\":false}"
    fi
    
    cat > backup-instance.json <<EOF
{
  "properties": {
    "friendlyName": "aks-backup-instance",
    "dataSourceInfo": {
      "resourceID": "${AKS_CLUSTER_ID}",
      "resourceLocation": "${LOCATION}",
      "datasourceType": "Microsoft.ContainerService/managedClusters",
      "objectType": "Datasource"
    },
    "policyInfo": {
      "policyId": "${POLICY_ID}"
    },
    "datasourceAuthCredentials": {
      "objectType": "SecretStoreBasedAuthCredentials",
      "secretStoreResource": {
        "uri": "${AKS_CLUSTER_ID}",
        "secretStoreType": "AzureKubernetesService"
      }
    },
    "objectType": "BackupInstance"
  }
}
EOF
    
    # Configure the backup instance
    az dataprotection backup-instance initialize \
        --datasource-id "${AKS_CLUSTER_ID}" \
        --datasource-type "Microsoft.ContainerService/managedClusters" \
        --policy-id "${POLICY_ID}" \
        --backup-configuration "${NAMESPACE_CONFIG}" \
        --snapshot-resource-group-id "${SNAPSHOT_RG_ID}" \
        > backup-instance-config.json
    
    # Create the backup instance
    az dataprotection backup-instance create \
        --resource-group "${RESOURCE_GROUP}" \
        --vault-name "${BACKUP_VAULT_NAME}" \
        --backup-instance backup-instance-config.json \
        --validate-for-backup
    
    log_info "Backup instance configured successfully."
    
    # Clean up temporary files
    rm -f backup-instance.json backup-instance-config.json
}

# Main execution
main() {
    log_info "Starting AKS Backup Configuration..."
    
    check_prerequisites
    set_subscription
    get_aks_credentials
    create_snapshot_resource_group
    create_storage_account
    create_backup_vault
    install_backup_extension
    enable_trusted_access
    create_backup_policy
    configure_backup_instance
    
    log_info "AKS Backup Configuration completed successfully!"
    log_info "Backup vault: ${BACKUP_VAULT_NAME}"
    log_info "Backup policy: ${BACKUP_POLICY_NAME}"
    log_info "Backups will run every 4 hours and be retained for 7 days."
}

# Run the script
main "$@"
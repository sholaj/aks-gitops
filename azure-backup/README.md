# AKS Backup Configuration with Azure Backup

This repository contains scripts and documentation for implementing Azure Backup for AKS clusters with a focus on backing up namespaces matching the "ATXXXX" pattern.

## Overview

Azure Backup for AKS provides a comprehensive solution for protecting Kubernetes workloads running in Azure Kubernetes Service. This implementation specifically targets user namespaces with the "ATXXXX" prefix pattern while providing flexibility for full cluster backups.

## Architecture

The backup solution consists of the following components:

- **Backup Vault**: Central repository for storing backup data
- **Backup Extension**: Installed on the AKS cluster to facilitate backups
- **Backup Policy**: Defines backup frequency and retention periods
- **Snapshot Resource Group**: Stores disk snapshots for faster restoration
- **Trusted Access**: Secure connection between AKS and Backup Vault

## Prerequisites

Before running the backup configuration, ensure you have:

1. **Azure CLI** installed (version 2.50.0 or later)
2. **kubectl** installed and configured
3. **kubelogin** for Azure AD authentication
4. **jq** for JSON processing
5. Appropriate Azure permissions:
   - Contributor role on the AKS cluster
   - Backup Contributor role on the resource group
   - Storage Account Contributor for snapshot storage

## Configuration

The scripts use the following default configuration (can be modified in the scripts):

```bash
SUBSCRIPTION_ID="469b61e7-a78a-4d21-b39e-3b130e4b8e2b"
RESOURCE_GROUP="AT39473-weu-dev-d01"
AKS_CLUSTER_NAME="uk8s-tsshared-weu-gt025-int-d01"
LOCATION="westeurope"
```

## Installation

### Step 1: Setup Backup Configuration

Run the setup script to configure Azure Backup for your AKS cluster:

```bash
chmod +x setup-aks-backup.sh
./setup-aks-backup.sh
```

This script will:
1. Create a snapshot resource group for storing disk snapshots
2. Create a storage account for the backup extension
3. Create a backup vault in the same region as your AKS cluster
4. Install the backup extension on the AKS cluster
5. Enable trusted access between AKS and the backup vault
6. Create a backup policy with 4-hour intervals and 7-day retention
7. Configure backup for namespaces matching "ATXXXX" pattern
8. Validate the backup configuration

### Step 2: Verify Backup Configuration

After setup, verify the backup configuration:

```bash
# Check backup vault status
az dataprotection backup-vault show \
  --resource-group AT39473-weu-dev-d01 \
  --vault-name aks-backup-vault-uk8s-tsshared-weu-gt025-int-d01

# Check backup instances
az dataprotection backup-instance list \
  --resource-group AT39473-weu-dev-d01 \
  --vault-name aks-backup-vault-uk8s-tsshared-weu-gt025-int-d01

# Check backup extension status
kubectl get pods -n dataprotection-microsoft
```

## Backup Operations

### Scheduled Backups

Backups run automatically every 4 hours based on the configured policy. The backup includes:
- Kubernetes resource configurations (deployments, services, configmaps, etc.)
- Persistent Volume snapshots (Azure Disk CSI volumes)
- Cluster state for selected namespaces

### Ad-hoc Backup

To trigger an immediate backup:

```bash
chmod +x restore-aks-backup.sh
./restore-aks-backup.sh
# Select option 5: Trigger ad-hoc backup
```

### Monitoring Backups

View backup jobs and their status:

```bash
# List all backup jobs
az dataprotection job list \
  --resource-group AT39473-weu-dev-d01 \
  --vault-name aks-backup-vault-uk8s-tsshared-weu-gt025-int-d01 \
  --output table

# Get details of a specific job
az dataprotection job show \
  --resource-group AT39473-weu-dev-d01 \
  --vault-name aks-backup-vault-uk8s-tsshared-weu-gt025-int-d01 \
  --job-id <job-id>
```

## Restoration Process

### Using the Restoration Script

The restoration script provides an interactive menu for various restore scenarios:

```bash
./restore-aks-backup.sh
```

Available restore options:
1. **List Recovery Points**: View all available backup snapshots
2. **Full Cluster Restore**: Restore all backed-up resources
3. **Namespace Restore**: Restore specific namespaces
4. **Item-Level Restore**: Restore specific resource types
5. **Trigger Ad-hoc Backup**: Create an immediate backup
6. **Verify Cluster State**: Check current cluster resources

### Restore Types

#### Full Cluster Restore
Restores all resources that were backed up, including:
- All namespaces matching the backup configuration
- All resource types within those namespaces
- Associated persistent volumes

#### Namespace Restore
Allows selective restoration of specific namespaces:
- Choose individual namespaces to restore
- Useful for recovering specific applications
- Preserves other namespaces unchanged

#### Item-Level Restore
Granular restoration of specific resource types:
- Select resource types (e.g., deployments, services, configmaps)
- Choose target namespaces
- Ideal for recovering specific configurations

### Restore Considerations

Before performing a restore:

1. **Backup Current State**: Consider backing up the current state before restoration
2. **Resource Conflicts**: Ensure target namespaces can be overwritten or are empty
3. **Application Dependencies**: Check for cross-namespace dependencies
4. **Storage Requirements**: Ensure sufficient storage for restored persistent volumes
5. **Network Policies**: Verify network policies won't block restored resources

## Namespace Pattern Matching

The backup configuration automatically identifies namespaces with the "ATXXXX" pattern where:
- "AT" is the literal prefix
- "XXXX" represents 4 or more digits

Example matching namespaces:
- AT1234
- AT39473
- AT99999
- AT123456

If no matching namespaces are found, the script will configure backup for all namespaces.

## Backup Hooks (Optional)

For application-consistent backups, you can configure backup hooks:

```yaml
apiVersion: dataprotection.microsoft.com/v1alpha1
kind: BackupHook
metadata:
  name: app-backup-hook
  namespace: AT1234
spec:
  preHooks:
    - exec:
        command: ["/bin/sh", "-c", "mysqldump -u root -p$MYSQL_ROOT_PASSWORD --all-databases > /backup/dump.sql"]
        container: mysql
        onError: Fail
        timeout: 60
  postHooks:
    - exec:
        command: ["/bin/sh", "-c", "rm /backup/dump.sql"]
        container: mysql
        onError: Continue
        timeout: 30
```

Deploy the hook:
```bash
kubectl apply -f backup-hook.yaml
```

## Troubleshooting

### Common Issues

1. **Backup Extension Installation Fails**
   ```bash
   # Check extension status
   az k8s-extension show \
     --name azure-aks-backup \
     --cluster-type managedClusters \
     --cluster-name uk8s-tsshared-weu-gt025-int-d01 \
     --resource-group AT39473-weu-dev-d01
   
   # Check pods
   kubectl get pods -n dataprotection-microsoft
   ```

2. **Trusted Access Issues**
   ```bash
   # List trusted access role bindings
   az aks trustedaccess rolebinding list \
     --cluster-name uk8s-tsshared-weu-gt025-int-d01 \
     --resource-group AT39473-weu-dev-d01
   ```

3. **Backup Job Failures**
   ```bash
   # Get error details
   az dataprotection job show \
     --resource-group AT39473-weu-dev-d01 \
     --vault-name aks-backup-vault-uk8s-tsshared-weu-gt025-int-d01 \
     --job-id <failed-job-id> \
     --query "properties.errorDetails"
   ```

### Logs and Diagnostics

```bash
# Extension logs
kubectl logs -n dataprotection-microsoft -l app=dataprotection-microsoft

# Backup vault diagnostics
az monitor diagnostic-settings create \
  --resource <vault-resource-id> \
  --name aks-backup-diagnostics \
  --workspace <log-analytics-workspace-id> \
  --logs '[{"category": "AzureBackupReport", "enabled": true}]'
```

## Security Considerations

1. **Access Control**: Implement RBAC for backup operations
2. **Encryption**: Backups are encrypted at rest using Azure managed keys
3. **Network Security**: Use Private Endpoints for backup vault if required
4. **Audit Logging**: Enable diagnostic settings for compliance
5. **Secret Management**: Store sensitive configuration in Azure Key Vault

## Limitations

- Only supports Azure Disk CSI driver volumes
- Persistent volumes must be ≤ 1 TB for vault tier backups
- Cannot restore to the same namespace without deleting existing resources
- Minimum backup interval is 4 hours
- Maximum retention period is 360 days

## Cost Optimization

1. **Snapshot Management**: Regularly clean up old snapshots
2. **Retention Policy**: Adjust retention based on compliance requirements
3. **Storage Redundancy**: Use LRS for non-critical environments
4. **Backup Frequency**: Balance between RPO requirements and costs

## Maintenance

### Regular Tasks

1. **Weekly**: Review backup job success rates
2. **Monthly**: Test restoration process
3. **Quarterly**: Review and update backup policies
4. **Annually**: Disaster recovery drill

### Updating Backup Configuration

To modify backup settings:

```bash
# Update backup policy
az dataprotection backup-policy update \
  --resource-group AT39473-weu-dev-d01 \
  --vault-name aks-backup-vault-uk8s-tsshared-weu-gt025-int-d01 \
  --policy-name aks-backup-policy-daily \
  --policy <updated-policy.json>

# Update backup instance
az dataprotection backup-instance update \
  --resource-group AT39473-weu-dev-d01 \
  --vault-name aks-backup-vault-uk8s-tsshared-weu-gt025-int-d01 \
  --backup-instance-name <instance-name> \
  --backup-instance <updated-config.json>
```

## Support and References

- [Azure Backup for AKS Documentation](https://learn.microsoft.com/en-us/azure/backup/azure-kubernetes-service-backup-overview)
- [AKS Backup Best Practices](https://learn.microsoft.com/en-us/azure/backup/azure-kubernetes-service-cluster-backup)
- [Azure Backup Pricing](https://azure.microsoft.com/pricing/details/backup/)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)

## License

This project is provided as-is for reference implementation of AKS backup solutions.

## Contributing

For improvements or issues, please follow your organization's contribution guidelines.
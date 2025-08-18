terraform {
  required_version = ">= 1.3.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.9.0"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatebackup"
    container_name       = "tfstate"
    key                  = "aks-backup.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
}

provider "azapi" {
  subscription_id = var.subscription_id
}

locals {
  location_short = {
    "westeurope"     = "weu"
    "northeurope"    = "neu"
    "eastus"         = "eus"
    "westus"         = "wus"
    "uksouth"        = "uks"
    "ukwest"         = "ukw"
  }
  
  location_code = lookup(local.location_short, var.location, "weu")
  
  backup_vault_name = "bvault-${var.aks_cluster_name}-${local.location_code}"
  snapshot_rg_name  = "${var.resource_group_name}-backup-snapshots"
  
  common_tags = merge(
    var.tags,
    {
      "ManagedBy"   = "Terraform"
      "Purpose"     = "AKS-Backup"
      "Environment" = var.environment
      "CreatedDate" = timestamp()
    }
  )
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = var.resource_group_name
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_resource_group" "snapshot" {
  name     = local.snapshot_rg_name
  location = var.location
  tags     = local.common_tags
}

resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_storage_account" "backup" {
  name                     = "aksbackup${random_string.storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 7
    }
    
    container_delete_retention_policy {
      days = 7
    }
  }
  
  network_rules {
    default_action = "Allow"
    bypass         = ["AzureServices"]
  }
  
  tags = local.common_tags
}

resource "azurerm_storage_container" "backup" {
  name                  = "aksbackupcontainer"
  storage_account_name  = azurerm_storage_account.backup.name
  container_access_type = "private"
}

resource "azurerm_data_protection_backup_vault" "aks" {
  name                = local.backup_vault_name
  resource_group_name = var.resource_group_name
  location            = var.location
  datastore_type      = "VaultStore"
  redundancy          = var.backup_vault_redundancy
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = local.common_tags
}

resource "azurerm_role_assignment" "backup_vault_contributor" {
  scope                = data.azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_data_protection_backup_vault.aks.identity[0].principal_id
  
  depends_on = [azurerm_data_protection_backup_vault.aks]
}

resource "azurerm_role_assignment" "backup_vault_storage_contributor" {
  scope                = azurerm_storage_account.backup.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_protection_backup_vault.aks.identity[0].principal_id
  
  depends_on = [azurerm_data_protection_backup_vault.aks]
}

resource "azurerm_role_assignment" "backup_vault_snapshot_contributor" {
  scope                = azurerm_resource_group.snapshot.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_data_protection_backup_vault.aks.identity[0].principal_id
  
  depends_on = [azurerm_data_protection_backup_vault.aks]
}

resource "azapi_resource" "backup_extension" {
  type      = "Microsoft.KubernetesConfiguration/extensions@2023-05-01"
  name      = "azure-aks-backup"
  parent_id = data.azurerm_kubernetes_cluster.aks.id
  
  body = jsonencode({
    properties = {
      extensionType = "microsoft.dataprotection.kubernetes"
      scope = {
        cluster = {
          releaseNamespace = "dataprotection-microsoft"
        }
      }
      configurationSettings = {
        "configuration.backupStorageLocation.bucket"                = azurerm_storage_container.backup.name
        "configuration.backupStorageLocation.config.resourceGroup"  = var.resource_group_name
        "configuration.backupStorageLocation.config.storageAccount" = azurerm_storage_account.backup.name
        "configuration.backupStorageLocation.config.subscriptionId" = var.subscription_id
        "credentials.tenantId"                                      = data.azurerm_kubernetes_cluster.aks.identity[0].tenant_id
      }
      configurationProtectedSettings = {}
    }
  })
  
  depends_on = [
    azurerm_storage_container.backup,
    azurerm_role_assignment.backup_vault_contributor
  ]
}

resource "azapi_resource" "trusted_access" {
  type      = "Microsoft.ContainerService/managedClusters/trustedAccessRoleBindings@2023-10-01"
  name      = "backup-trusted-access"
  parent_id = data.azurerm_kubernetes_cluster.aks.id
  
  body = jsonencode({
    properties = {
      sourceResourceId = azurerm_data_protection_backup_vault.aks.id
      roles = [
        "Microsoft.DataProtection/backupVaults/backup-operator"
      ]
    }
  })
  
  depends_on = [
    azurerm_data_protection_backup_vault.aks,
    azapi_resource.backup_extension
  ]
}

resource "azurerm_data_protection_backup_policy_kubernetes_cluster" "aks" {
  name                = "${var.backup_policy_name_prefix}-${var.backup_frequency}"
  resource_group_name = var.resource_group_name
  vault_name          = azurerm_data_protection_backup_vault.aks.name
  
  backup_repeating_time_intervals = var.backup_schedule
  
  retention_rule {
    name     = "Default"
    priority = 99
    
    life_cycle {
      duration        = "P${var.retention_days}D"
      data_store_type = "OperationalStore"
    }
    
    criteria {
      absolute_criteria = "FirstOfDay"
    }
  }
  
  dynamic "retention_rule" {
    for_each = var.enable_weekly_retention ? [1] : []
    content {
      name     = "Weekly"
      priority = 20
      
      life_cycle {
        duration        = "P${var.weekly_retention_weeks}W"
        data_store_type = "OperationalStore"
      }
      
      criteria {
        absolute_criteria      = "FirstOfWeek"
        days_of_week           = var.weekly_retention_days
        weeks_of_month         = []
        months_of_year         = []
        scheduled_backup_times = []
      }
    }
  }
  
  dynamic "retention_rule" {
    for_each = var.enable_monthly_retention ? [1] : []
    content {
      name     = "Monthly"
      priority = 15
      
      life_cycle {
        duration        = "P${var.monthly_retention_months}M"
        data_store_type = "OperationalStore"
      }
      
      criteria {
        absolute_criteria      = "FirstOfMonth"
        days_of_week           = []
        weeks_of_month         = var.monthly_retention_weeks
        months_of_year         = []
        scheduled_backup_times = []
      }
    }
  }
  
  default_retention_rule {
    life_cycle {
      duration        = "P${var.default_retention_days}D"
      data_store_type = "OperationalStore"
    }
  }
  
  depends_on = [azurerm_data_protection_backup_vault.aks]
}

resource "azurerm_data_protection_backup_instance_kubernetes_cluster" "aks" {
  name                         = "aks-backup-instance"
  kubernetes_cluster_id        = data.azurerm_kubernetes_cluster.aks.id
  vault_id                     = azurerm_data_protection_backup_vault.aks.id
  location                     = var.location
  backup_policy_id             = azurerm_data_protection_backup_policy_kubernetes_cluster.aks.id
  snapshot_resource_group_name = azurerm_resource_group.snapshot.name
  
  backup_datasource_parameters {
    excluded_namespaces              = var.excluded_namespaces
    included_namespaces              = var.included_namespaces
    excluded_resource_types          = var.excluded_resource_types
    included_cluster_scoped_resources = var.include_cluster_resources
    included_namespaces              = var.included_namespaces
    label_selectors                  = var.label_selectors
    volume_snapshot_enabled          = var.enable_volume_snapshots
  }
  
  depends_on = [
    azapi_resource.trusted_access,
    azurerm_data_protection_backup_policy_kubernetes_cluster.aks,
    azurerm_role_assignment.backup_vault_contributor,
    azurerm_role_assignment.backup_vault_storage_contributor,
    azurerm_role_assignment.backup_vault_snapshot_contributor
  ]
}

output "backup_vault_id" {
  value       = azurerm_data_protection_backup_vault.aks.id
  description = "The ID of the backup vault"
}

output "backup_vault_name" {
  value       = azurerm_data_protection_backup_vault.aks.name
  description = "The name of the backup vault"
}

output "backup_policy_id" {
  value       = azurerm_data_protection_backup_policy_kubernetes_cluster.aks.id
  description = "The ID of the backup policy"
}

output "backup_instance_id" {
  value       = azurerm_data_protection_backup_instance_kubernetes_cluster.aks.id
  description = "The ID of the backup instance"
}

output "storage_account_name" {
  value       = azurerm_storage_account.backup.name
  description = "The name of the storage account used for backups"
}

output "snapshot_resource_group_name" {
  value       = azurerm_resource_group.snapshot.name
  description = "The name of the resource group for snapshots"
}
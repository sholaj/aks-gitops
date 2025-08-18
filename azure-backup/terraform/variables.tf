variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
  default     = "469b61e7-a78a-4d21-b39e-3b130e4b8e2b"
}

variable "resource_group_name" {
  description = "The name of the resource group containing the AKS cluster"
  type        = string
  default     = "AT39473-weu-dev-d01"
}

variable "aks_cluster_name" {
  description = "The name of the AKS cluster to backup"
  type        = string
  default     = "uk8s-tsshared-weu-gt025-int-d01"
}

variable "location" {
  description = "The Azure region for resources"
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "The environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}

variable "backup_frequency" {
  description = "Backup frequency (hourly, daily)"
  type        = string
  default     = "hourly"
  
  validation {
    condition     = contains(["hourly", "daily"], var.backup_frequency)
    error_message = "Backup frequency must be either 'hourly' or 'daily'"
  }
}

variable "backup_schedule" {
  description = "Backup schedule in ISO 8601 format"
  type        = list(string)
  default     = ["R/2024-01-01T00:00:00+00:00/PT4H"]
}

variable "retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 360
    error_message = "Retention days must be between 1 and 360"
  }
}

variable "default_retention_days" {
  description = "Default retention period in days"
  type        = number
  default     = 7
}

variable "enable_weekly_retention" {
  description = "Enable weekly retention rule"
  type        = bool
  default     = true
}

variable "weekly_retention_weeks" {
  description = "Number of weeks to retain weekly backups"
  type        = number
  default     = 4
}

variable "weekly_retention_days" {
  description = "Days of week for weekly retention"
  type        = list(string)
  default     = ["Sunday"]
}

variable "enable_monthly_retention" {
  description = "Enable monthly retention rule"
  type        = bool
  default     = true
}

variable "monthly_retention_months" {
  description = "Number of months to retain monthly backups"
  type        = number
  default     = 12
}

variable "monthly_retention_weeks" {
  description = "Weeks of month for monthly retention"
  type        = list(string)
  default     = ["First"]
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
  
  validation {
    condition     = contains(["LRS", "GRS", "ZRS", "RAGRS"], var.storage_replication_type)
    error_message = "Storage replication type must be one of: LRS, GRS, ZRS, RAGRS"
  }
}

variable "backup_vault_redundancy" {
  description = "Backup vault redundancy type"
  type        = string
  default     = "LocallyRedundant"
  
  validation {
    condition     = contains(["LocallyRedundant", "GeoRedundant", "ZoneRedundant"], var.backup_vault_redundancy)
    error_message = "Backup vault redundancy must be one of: LocallyRedundant, GeoRedundant, ZoneRedundant"
  }
}

variable "backup_policy_name_prefix" {
  description = "Prefix for backup policy name"
  type        = string
  default     = "aks-backup-policy"
}

variable "included_namespaces" {
  description = "List of namespaces to include in backup (empty means all)"
  type        = list(string)
  default     = []
}

variable "excluded_namespaces" {
  description = "List of namespaces to exclude from backup"
  type        = list(string)
  default     = ["kube-system", "kube-public", "kube-node-lease", "dataprotection-microsoft"]
}

variable "excluded_resource_types" {
  description = "List of resource types to exclude from backup"
  type        = list(string)
  default     = []
}

variable "include_cluster_resources" {
  description = "Include cluster-scoped resources in backup"
  type        = bool
  default     = false
}

variable "label_selectors" {
  description = "Label selectors for resources to backup"
  type        = list(string)
  default     = []
}

variable "enable_volume_snapshots" {
  description = "Enable volume snapshots for persistent volumes"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
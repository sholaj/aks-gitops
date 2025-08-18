# Namespace Discovery Module for ATXXXX Pattern
# This module dynamically discovers namespaces matching the ATXXXX pattern

data "external" "discover_namespaces" {
  program = ["bash", "${path.module}/../scripts/discover-namespaces.sh"]
  
  query = {
    cluster_name    = var.aks_cluster_name
    resource_group  = var.resource_group_name
    subscription_id = var.subscription_id
    pattern         = "^AT[0-9]{4,}"
  }
}

locals {
  discovered_namespaces = try(jsondecode(data.external.discover_namespaces.result.namespaces), [])
  
  # Merge discovered namespaces with manually specified ones
  all_included_namespaces = distinct(concat(
    local.discovered_namespaces,
    var.included_namespaces
  ))
  
  # Final namespace list for backup
  final_included_namespaces = length(local.all_included_namespaces) > 0 ? local.all_included_namespaces : []
}

output "discovered_namespaces" {
  value       = local.discovered_namespaces
  description = "Namespaces discovered with ATXXXX pattern"
}

output "final_backup_namespaces" {
  value       = local.final_included_namespaces
  description = "Final list of namespaces to be backed up"
}
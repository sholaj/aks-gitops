# AKS Version Test

Simple InSpec profile to verify AKS cluster is running Kubernetes version 1.32.x

## Usage

1. Install dependencies:
```bash
cd aks-version-test
inspec vendor .
```

2. Run the test:
```bash
# Using environment variables
export AZURE_RESOURCE_GROUP="your-resource-group"
export AKS_CLUSTER_NAME="your-aks-cluster"
inspec exec . -t azure://

# Or with input file
inspec exec . -t azure:// --input resource_group_name=your-rg aks_cluster_name=your-cluster
```

## Prerequisites

- Azure CLI authenticated (`az login`)
- InSpec installed
- Access to the target AKS cluster

## What it tests

- AKS cluster exists
- Kubernetes version matches 1.32.x pattern
- Version is not older than 1.32
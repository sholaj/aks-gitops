#!/bin/bash

# Namespace Discovery Script for Terraform
# This script discovers namespaces matching a pattern and returns them as JSON

set -e

# Parse input JSON
eval "$(jq -r '@sh "CLUSTER_NAME=\(.cluster_name) RESOURCE_GROUP=\(.resource_group) SUBSCRIPTION_ID=\(.subscription_id) PATTERN=\(.pattern)"')"

# Set subscription
az account set --subscription "${SUBSCRIPTION_ID}" 2>/dev/null || true

# Get AKS credentials
az aks get-credentials \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${CLUSTER_NAME}" \
  --overwrite-existing &>/dev/null || true

# Convert kubeconfig
kubelogin convert-kubeconfig -l azurecli &>/dev/null || true

# Discover namespaces matching pattern
NAMESPACES=$(kubectl get namespaces -o json 2>/dev/null | \
  jq -r --arg pattern "${PATTERN}" \
  '.items[].metadata.name | select(test($pattern))' | \
  jq -R -s -c 'split("\n") | map(select(length > 0))' || echo "[]")

# Return as JSON
jq -n --argjson namespaces "${NAMESPACES}" '{"namespaces": ($namespaces | @json)}'
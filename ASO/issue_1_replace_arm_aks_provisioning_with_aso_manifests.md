# Replace ARM AKS Provisioning with ASO Manifests

Labels: aso, aks, infrastructure-as-code

As a platform engineer  
I want to use Azure Service Operator (ASO) to provision AKS clusters declaratively  
So that I can enable GitOps-native, Kubernetes-aligned infrastructure management

### Acceptance Criteria
- `ManagedCluster` ASO manifests exist under `infrastructure/aks/managed-cluster.yaml`
- FluxCD successfully reconciles the AKS cluster from Git
- Cluster includes identity, auto-upgrade, and network profile configurations
- Validation testing confirms cluster is reachable post-deploy

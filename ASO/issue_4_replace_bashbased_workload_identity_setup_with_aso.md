# Replace Bash-Based Workload Identity Setup with ASO

Labels: aso, identity, workloadidentity

As a platform engineer  
I want to manage User Assigned Managed Identities using ASO  
So that identity lifecycle is GitOps-driven and RBAC compliant

### Acceptance Criteria
- UAMI defined in `infrastructure/identity/user-assigned-identity.yaml`
- Cluster identity reference correctly wired to AKS ASO object
- Role assignment logic externalized or replaced via Flux/OPA if necessary
- InSpec tests confirm identity presence and usage

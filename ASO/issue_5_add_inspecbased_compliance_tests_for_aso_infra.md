# Add InSpec-Based Compliance Tests for ASO Infra

Labels: compliance, inspec, aks

As a security-conscious engineer  
I want to validate ASO-provisioned resources using InSpec  
So that I ensure compliance with Azure security and tagging policies

### Acceptance Criteria
- InSpec profiles defined for AKS, KeyVault, UAMI
- GitLab test stage added to run `inspec exec` against Azure subscription
- Reports uploaded as artifacts and optionally sent to a dashboard or email
- Includes at least 3 tests per resource type (e.g. `rbac_enabled`, `vnet_injected`, `kv_access_allowed`)

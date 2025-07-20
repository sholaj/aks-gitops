

⸻

✅ 1. AKS Cluster Compliance

File: controls/aks_profile.rb

Test	Description
✅ RBAC enabled	enableRBAC: true must be enforced
✅ Private cluster	Cluster must have enablePrivateCluster: true
✅ OIDC issuer profile	Validate that oidcIssuerProfile.enabled is correctly set
✅ Network policy	Ensure networkPolicy = cilium or equivalent
✅ Secure API server	Test for disableRunCommand = true
✅ Auto-upgrade enabled	Check autoUpgradeProfile.upgradeChannel = patch
✅ Image cleaner	Ensure image garbage collection is enabled via imageCleaner
✅ Workload identity	Confirm workloadIdentity.enabled = true


⸻

✅ 2. Node Pool Compliance

File: controls/nodepool_profile.rb

Test	Description
✅ Host encryption	Ensure enableEncryptionAtHost: true on all node pools
✅ Secure boot & vTPM	Confirm securityProfile.enableSecureBoot: true and enableVtpm: true
✅ SSH access disabled	Validate sshAccess: Disabled
✅ CriticalAddonsOnly taint	Verify CriticalAddonsOnly=true:NoSchedule taint on system pools
✅ OS SKU & type	Check for osType: Linux and osSku: AzureLinux


⸻

✅ 3. Identity Compliance

File: controls/identity_profile.rb

Test	Description
✅ UAMI exists	Validate User Assigned Managed Identity is deployed
✅ UAMI used	Check AKS control plane references the correct UAMI
✅ Kubelet identity set	Validate correct identity assignment to kubelet
✅ No role assignment drift	Optionally check roles via Azure API or OPA policy integration


⸻

✅ 4. Key Vault & Secrets Compliance

File: controls/keyvault_profile.rb

Test	Description
✅ CSI Secrets driver enabled	Check azureKeyvaultSecretsProvider.enabled = true
✅ Secret access permission	Validate get permissions for secrets/certs/keys are assigned
✅ AccessPolicy matches UAMI	Match principalId in policy to UAMI objectId
✅ Secret rotation interval	Confirm rotationPollInterval = 30m or as defined


⸻

✅ 5. Networking & Observability

File: controls/networking_profile.rb

Test	Description
✅ Advanced networking	Check networkPlugin = azure, networkPluginMode = overlay
✅ Cilium dataplane	Ensure ebpfDataplane = cilium
✅ Monitoring enabled	Test that omsagent, azureMonitorProfile are active
✅ DNS & service CIDRs	Validate clusterServiceCidr, dnsServiceIP, podCidr values


⸻


⸻

📁 Suggested Folder Layout for Controls

tests/inspec/controls/
├── aks_profile.rb
├── nodepool_profile.rb
├── identity_profile.rb
├── keyvault_profile.rb
├── networking_profile.rb
├── governance_profile.rb


⸻
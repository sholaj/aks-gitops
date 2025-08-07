# Azure Kubernetes Service (AKS) Compliance Controls
# These controls validate AKS clusters provisioned by Azure Service Operator (ASO)

control 'aks-rbac-enabled' do
  impact 1.0
  title 'AKS cluster should have RBAC enabled'
  desc 'Role-Based Access Control (RBAC) provides granular access management for Kubernetes resources'
  desc 'rationale', 'RBAC is essential for security and compliance in Kubernetes environments'
  desc 'remediation', 'Enable RBAC during cluster creation or recreate the cluster with RBAC enabled'
  tag 'CIS': ['CIS-5.2.1']
  tag 'Azure Security Benchmark': ['ASB-4.1']
  tag 'NIST': ['AC-3']
  ref 'Azure AKS RBAC Documentation', url: 'https://docs.microsoft.com/en-us/azure/aks/azure-ad-rbac'

  describe azurerm_kubernetes_cluster(resource_group: input('resource_group_name'), name: input('aks_cluster_name')) do
    it { should exist }
    its('enable_rbac') { should cmp true }
  end
end

control 'aks-network-policy-enabled' do
  impact 1.0
  title 'AKS cluster should have network policy enabled'
  desc 'Network policies provide micro-segmentation within the Kubernetes cluster'
  desc 'rationale', 'Network policies help prevent lateral movement and contain security breaches'
  desc 'remediation', 'Enable network policy (Azure or Calico) during cluster creation'
  tag 'CIS': ['CIS-5.3.2']
  tag 'Azure Security Benchmark': ['ASB-9.2']
  tag 'NIST': ['SC-7']

  describe azurerm_kubernetes_cluster(resource_group: input('resource_group_name'), name: input('aks_cluster_name')) do
    it { should exist }
    its('network_profile') { should_not be_nil }
    its('network_profile.network_policy') { should_not be_nil }
    its('network_profile.network_policy') { should match(/azure|calico/i) }
  end
end

control 'aks-node-pool-encryption' do
  impact 1.0
  title 'AKS node pools should have host encryption enabled'
  desc 'Host-based encryption provides encryption at rest for the VM host cache and OS/temp disks'
  desc 'rationale', 'Encryption at host ensures data protection even if the underlying infrastructure is compromised'
  desc 'remediation', 'Enable encryption at host for all node pools'
  tag 'CIS': ['CIS-2.1.1']
  tag 'Azure Security Benchmark': ['ASB-8.1']
  tag 'NIST': ['SC-28']

  describe azurerm_kubernetes_cluster(resource_group: input('resource_group_name'), name: input('aks_cluster_name')) do
    it { should exist }
    its('agent_pool_profiles') { should_not be_empty }
    its('agent_pool_profiles') do
      should all(satisfy do |profile|
        profile.key?('enable_encryption_at_host') && profile['enable_encryption_at_host'] == true
      end)
    end
  end
end

control 'aks-cluster-monitoring' do
  impact 0.8
  title 'AKS cluster should have monitoring enabled'
  desc 'Container insights provides comprehensive monitoring for AKS clusters'
  desc 'rationale', 'Monitoring is essential for security incident detection and operational visibility'
  desc 'remediation', 'Enable Container Insights through Azure Monitor'
  tag 'Azure Security Benchmark': ['ASB-6.3']
  tag 'NIST': ['SI-4']

  describe azurerm_kubernetes_cluster(resource_group: input('resource_group_name'), name: input('aks_cluster_name')) do
    it { should exist }
    its('addon_profile') { should_not be_nil }
    its('addon_profile.oms_agent') { should_not be_nil }
    its('addon_profile.oms_agent.enabled') { should cmp true }
  end
end

control 'aks-cluster-tagging' do
  impact 0.5
  title 'AKS cluster should have required tags'
  desc 'Proper tagging ensures resource governance and cost management'
  desc 'rationale', 'Tags are essential for resource management, cost allocation, and compliance tracking'
  desc 'remediation', 'Add all required tags to the AKS cluster resource'
  tag 'Governance': ['Tagging']

  required_tags = input('required_tags')
  
  describe azurerm_resource(resource_group: input('resource_group_name'), 
                           name: input('aks_cluster_name'), 
                           type: 'Microsoft.ContainerService/managedClusters') do
    it { should exist }
    required_tags.each do |tag|
      its('tags') { should include(tag) }
      its("tags.#{tag}") { should_not be_empty }
    end
  end
end

control 'aks-api-server-authorized-ip-ranges' do
  impact 0.7
  title 'AKS API server should restrict access using authorized IP ranges'
  desc 'Authorized IP ranges limit access to the Kubernetes API server to specific IP addresses'
  desc 'rationale', 'Restricting API server access reduces the attack surface and prevents unauthorized access'
  desc 'remediation', 'Configure authorized IP ranges for the AKS API server'
  tag 'CIS': ['CIS-4.2.1']
  tag 'Azure Security Benchmark': ['ASB-9.1']
  tag 'NIST': ['AC-3']

  only_if('Skip this control in development environments') do
    input('environment') != 'dev'
  end

  describe azurerm_kubernetes_cluster(resource_group: input('resource_group_name'), name: input('aks_cluster_name')) do
    it { should exist }
    its('api_server_access_profile') { should_not be_nil }
    its('api_server_access_profile.authorized_ip_ranges') { should_not be_empty }
  end
end

control 'aks-private-cluster' do
  impact 0.8
  title 'AKS cluster should be configured as private cluster for production environments'
  desc 'Private clusters ensure the API server has no public IP and communicates through private networking'
  desc 'rationale', 'Private clusters provide better security by keeping the control plane isolated from the internet'
  desc 'remediation', 'Configure the cluster as private during creation'
  tag 'CIS': ['CIS-4.2.2']
  tag 'Azure Security Benchmark': ['ASB-9.3']

  only_if('Only enforce private cluster for production') do
    input('environment') == 'prod'
  end

  describe azurerm_kubernetes_cluster(resource_group: input('resource_group_name'), name: input('aks_cluster_name')) do
    it { should exist }
    its('private_cluster_enabled') { should cmp true }
  end
end

control 'aks-azure-ad-integration' do
  impact 0.9
  title 'AKS cluster should integrate with Azure Active Directory'
  desc 'Azure AD integration provides centralized identity management and enhanced security'
  desc 'rationale', 'Azure AD integration enables centralized user management and conditional access policies'
  desc 'remediation', 'Configure Azure AD integration during cluster creation'
  tag 'Azure Security Benchmark': ['ASB-4.2']
  tag 'NIST': ['IA-2']

  describe azurerm_kubernetes_cluster(resource_group: input('resource_group_name'), name: input('aks_cluster_name')) do
    it { should exist }
    its('aad_profile') { should_not be_nil }
    its('aad_profile.managed') { should cmp true }
  end
end
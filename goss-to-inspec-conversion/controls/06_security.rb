# encoding: utf-8
# copyright: DevOps Team

title '06 - Security'

# Retrieve inputs
resource_group = input('resource_group')
cluster_name = input('cluster_name')
log_analytics_workspace_id = input('log_analytics_workspace_id')
pod_identity_exceptions = input('pod_identity_exceptions')

control 'security-01' do
  impact 1.0
  title 'Security hardening should be applied'
  desc 'Verify that local accounts are disabled to enforce Azure AD authentication'
  
  tag 'security'
  tag 'authentication'
  tag 'hardening'
  tag 'cis-kubernetes-benchmark: 1.2.1'
  tag 'nist-csf: PR.AC-1'
  tag 'pci-dss: 8.1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'disableLocalAccounts' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'security-02' do
  impact 0.8
  title 'OMS agent should be enabled'
  desc 'Verify that the OMS agent addon is enabled for security monitoring'
  
  tag 'security'
  tag 'monitoring'
  tag 'logging'
  tag 'nist-csf: DE.CM-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'addonProfiles.omsagent.enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'security-03' do
  impact 0.8
  title 'OMS logs should be shipped to Log Analytics'
  desc 'Verify that logs are being shipped to the correct Log Analytics workspace'
  
  tag 'security'
  tag 'monitoring'
  tag 'logging'
  tag 'log-analytics'
  tag 'nist-csf: DE.CM-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/#{Regexp.escape(log_analytics_workspace_id)}/) }
  end
end

control 'security-04' do
  impact 1.0
  title 'Private cluster should be enabled'
  desc 'Verify that the AKS cluster is configured as a private cluster'
  
  tag 'security'
  tag 'networking'
  tag 'private-cluster'
  tag 'cis-kubernetes-benchmark: 1.2.3'
  tag 'nist-csf: PR.AC-4'
  tag 'pci-dss: 1.2'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'apiServerAccessProfile.enablePrivateCluster' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'security-05' do
  impact 0.7
  title 'Private cluster public FQDN should be configured'
  desc 'Verify private cluster public FQDN configuration for authorized access'
  
  tag 'security'
  tag 'networking'
  tag 'private-cluster'
  tag 'fqdn'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'apiServerAccessProfile.enablePrivateClusterPublicFqdn' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'security-06' do
  impact 0.6
  title 'Pod identity exceptions should be configured'
  desc 'Verify that pod identity exceptions are properly configured for specified namespaces'
  
  tag 'security'
  tag 'pod-identity'
  tag 'exceptions'
  tag 'nist-csf: PR.AC-1'
  
  # Default pod identity exceptions for system namespaces
  required_exceptions = ['kube-system', 'aks-system']
  all_exceptions = (pod_identity_exceptions + required_exceptions).uniq
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'podIdentityProfile.userAssignedIdentityExceptions' -o json") do
    its('exit_status') { should eq 0 }
    
    all_exceptions.each do |namespace|
      its('stdout') { should match(/#{Regexp.escape(namespace)}/) }
    end
  end
end

control 'security-07' do
  impact 0.8
  title 'Azure Policy addon should be enabled'
  desc 'Verify that Azure Policy addon is enabled for governance and compliance'
  
  tag 'security'
  tag 'policy'
  tag 'governance'
  tag 'compliance'
  tag 'nist-csf: PR.IP-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'addonProfiles.azurepolicy.enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end
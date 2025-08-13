# encoding: utf-8
# copyright: DevOps Team

title '02 - Workload Identity Setup'

# Retrieve inputs
resource_group = input('resource_group')
cluster_name = input('cluster_name')

control 'workload-identity-01' do
  impact 1.0
  title 'OIDC issuer URL should be configured'
  desc 'Verify that the OIDC issuer URL is properly configured for workload identity'
  
  tag 'workload-identity'
  tag 'security'
  tag 'authentication'
  tag 'nist-csf: PR.AC-1'
  tag 'cis-kubernetes-benchmark: 1.2.2'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'oidcIssuerProfile.issuerUrl' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/oic\.prod-aks\.azure\.com/) }
  end
end

control 'workload-identity-02' do
  impact 1.0
  title 'OIDC issuer should be enabled'
  desc 'Verify that the OIDC issuer is enabled on the AKS cluster'
  
  tag 'workload-identity'
  tag 'security'
  tag 'authentication'
  tag 'nist-csf: PR.AC-1'
  tag 'cis-kubernetes-benchmark: 1.2.2'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'oidcIssuerProfile.enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end
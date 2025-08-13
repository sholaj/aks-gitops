# encoding: utf-8
# copyright: DevOps Team

title '01 - Cluster-Level Properties'

# Retrieve inputs
resource_group = input('resource_group')
cluster_name = input('cluster_name')
kubernetes_version = input('kubernetes_version')
dns_prefix = input('dns_prefix')

control 'cluster-properties-01' do
  impact 1.0
  title 'Kubernetes version should match expected version'
  desc 'Verify that the AKS cluster is running the expected Kubernetes version'
  
  tag 'cluster'
  tag 'version'
  tag 'compliance'
  tag 'cis-kubernetes-benchmark: 1.1.1'
  tag 'nist-csf: ID.AM-2'
  
  describe command("kubectl version --short | grep 'Server Version' | awk '{print $3}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/#{Regexp.escape(kubernetes_version)}/) }
  end
end

control 'cluster-properties-02' do
  impact 0.7
  title 'DNS prefix should be configured correctly'
  desc 'Verify that the AKS cluster has the correct DNS prefix configured'
  
  tag 'cluster'
  tag 'dns'
  tag 'networking'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'dnsPrefix' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq dns_prefix }
  end
end

control 'cluster-properties-03' do
  impact 1.0
  title 'RBAC should be enabled'
  desc 'Verify that Role-Based Access Control (RBAC) is enabled on the AKS cluster'
  
  tag 'cluster'
  tag 'security'
  tag 'rbac'
  tag 'cis-kubernetes-benchmark: 1.2.1'
  tag 'nist-csf: PR.AC-1'
  tag 'pci-dss: 7.1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'enableRBAC' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'cluster-properties-04' do
  impact 0.5
  title 'HTTP application routing should be configured'
  desc 'Verify HTTP application routing addon configuration status'
  
  tag 'cluster'
  tag 'networking'
  tag 'addon'
  tag 'nist-csf: PR.AC-4'
  
  only_if { input('check_http_routing', value: true) }
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'addonProfiles.httpApplicationRouting.enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end
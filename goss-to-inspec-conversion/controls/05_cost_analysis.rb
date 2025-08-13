# encoding: utf-8
# copyright: DevOps Team

title '05 - Cost Analysis'

# Retrieve inputs
resource_group = input('resource_group')
cluster_name = input('cluster_name')

control 'cost-analysis-01' do
  impact 0.6
  title 'Cost analysis should be enabled'
  desc 'Verify that cost analysis is enabled for the AKS cluster'
  
  tag 'cost'
  tag 'monitoring'
  tag 'financial-governance'
  tag 'nist-csf: ID.GV-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'metricsProfile.costAnalysis.enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'cost-analysis-02' do
  impact 0.7
  title 'Azure Monitor metrics should be enabled'
  desc 'Verify that Azure Monitor metrics are enabled for cost and performance monitoring'
  
  tag 'cost'
  tag 'monitoring'
  tag 'azure-monitor'
  tag 'nist-csf: DE.CM-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'azureMonitorProfile.metrics.enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'cost-analysis-03' do
  impact 0.7
  title 'Container insights should be enabled'
  desc 'Verify that container insights are enabled for comprehensive monitoring'
  
  tag 'cost'
  tag 'monitoring'
  tag 'container-insights'
  tag 'observability'
  tag 'nist-csf: DE.CM-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'azureMonitorProfile.containerInsights.enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end
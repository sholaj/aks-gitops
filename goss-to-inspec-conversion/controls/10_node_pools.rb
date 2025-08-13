# encoding: utf-8
# copyright: DevOps Team

title '10 - Node Pool Configuration'

# Retrieve inputs
resource_group = input('resource_group')
cluster_name = input('cluster_name')
environment = input('environment', value: 'dev')

control 'nodepool-01' do
  impact 1.0
  title 'System node pool should be properly configured'
  desc 'Verify that the system node pool has proper configuration for security and performance'
  
  tag 'nodepool'
  tag 'system'
  tag 'security'
  tag 'performance'
  tag 'cis-kubernetes-benchmark: 4.1.1'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name sysnpl --query 'enableAutoScaling' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
  
  describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name sysnpl --query 'enableCustomCaTrust' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
  
  describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name sysnpl --query 'enableEncryptionAtHost' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'nodepool-02' do
  impact 1.0
  title 'User node pool should be properly configured'
  desc 'Verify that the user node pool has proper configuration for security and performance'
  
  tag 'nodepool'
  tag 'user'
  tag 'security'
  tag 'performance'
  tag 'cis-kubernetes-benchmark: 4.1.1'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name usrnpl --query 'enableAutoScaling' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
  
  describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name usrnpl --query 'enableCustomCaTrust' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
  
  describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name usrnpl --query 'enableEncryptionAtHost' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'nodepool-03' do
  impact 1.0
  title 'Node pools should have security profiles enabled'
  desc 'Verify that node pools have Secure Boot and vTPM enabled for enhanced security'
  
  tag 'nodepool'
  tag 'security'
  tag 'secure-boot'
  tag 'vtpm'
  tag 'trusted-computing'
  tag 'nist-csf: PR.DS-6'
  
  %w[sysnpl usrnpl].each do |pool_name|
    describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name #{pool_name} --query 'securityProfile.enableSecureBoot' -o tsv") do
      its('exit_status') { should eq 0 }
      its('stdout.strip') { should eq 'true' }
    end
    
    describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name #{pool_name} --query 'securityProfile.enableVtpm' -o tsv") do
      its('exit_status') { should eq 0 }
      its('stdout.strip') { should eq 'true' }
    end
  end
end

control 'nodepool-04' do
  impact 0.8
  title 'Node pools should use Azure Linux OS'
  desc 'Verify that node pools are configured to use Azure Linux for better security and performance'
  
  tag 'nodepool'
  tag 'os'
  tag 'azure-linux'
  tag 'security'
  tag 'performance'
  
  %w[sysnpl usrnpl].each do |pool_name|
    describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name #{pool_name} --query 'osSku' -o tsv") do
      its('exit_status') { should eq 0 }
      its('stdout.strip') { should eq 'AzureLinux' }
    end
    
    describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name #{pool_name} --query 'osType' -o tsv") do
      its('exit_status') { should eq 0 }
      its('stdout.strip') { should eq 'Linux' }
    end
  end
end

control 'nodepool-05' do
  impact 0.7
  title 'Node pools should use Virtual Machine Scale Sets'
  desc 'Verify that node pools are configured to use VMSS for better scalability'
  
  tag 'nodepool'
  tag 'scalability'
  tag 'vmss'
  tag 'performance'
  
  %w[sysnpl usrnpl].each do |pool_name|
    describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name #{pool_name} --query 'type' -o tsv") do
      its('exit_status') { should eq 0 }
      its('stdout.strip') { should eq 'VirtualMachineScaleSets' }
    end
    
    describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name #{pool_name} --query 'osDiskType' -o tsv") do
      its('exit_status') { should eq 0 }
      its('stdout.strip') { should eq 'Managed' }
    end
  end
end

control 'nodepool-06' do
  impact 0.6
  title 'User node pool should have appropriate minimum node count'
  desc 'Verify that user node pool has minimum node count set to 1'
  
  tag 'nodepool'
  tag 'scaling'
  tag 'capacity'
  tag 'cost-optimization'
  
  describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name usrnpl --query 'minCount' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq '1' }
  end
end

control 'nodepool-07' do
  impact 0.5
  title 'Node pools should have environment-appropriate maximum node counts'
  desc 'Verify that node pools have appropriate maximum node counts based on environment'
  
  tag 'nodepool'
  tag 'scaling'
  tag 'capacity'
  tag 'environment-specific'
  
  # Environment-specific max node counts
  expected_max_counts = {
    'dev' => { 'sysnpl' => '3', 'usrnpl' => '5' },
    'staging' => { 'sysnpl' => '5', 'usrnpl' => '10' },
    'prod' => { 'sysnpl' => '10', 'usrnpl' => '20' }
  }
  
  current_env_limits = expected_max_counts[environment] || expected_max_counts['dev']
  
  %w[sysnpl usrnpl].each do |pool_name|
    expected_max = current_env_limits[pool_name]
    
    describe command("az aks nodepool show --resource-group #{resource_group} --cluster-name #{cluster_name} --name #{pool_name} --query 'maxCount' -o tsv") do
      its('exit_status') { should eq 0 }
      its('stdout.strip') { should eq expected_max }
    end
  end
end
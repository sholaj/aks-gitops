# encoding: utf-8
# copyright: DevOps Team

title '09 - ARM Parameter File Creation'

# Retrieve inputs
resource_group = input('resource_group')
cluster_name = input('cluster_name')
kubernetes_version = input('kubernetes_version')
istio_version = input('istio_version')

control 'arm-params-01' do
  impact 0.6
  title 'Istio ASM version should be passed to ARM template'
  desc 'Verify that the correct Istio version is configured in ARM parameters'
  
  tag 'arm'
  tag 'parameters'
  tag 'istio'
  tag 'infrastructure-as-code'
  tag 'nist-csf: ID.AM-1'
  
  # This control assumes the updateParams.py script and related files exist
  # In a production environment, you would configure the actual paths
  only_if { input('validate_arm_parameters', value: false) }
  
  describe "ARM parameter validation for Istio version" do
    skip "ARM parameter validation requires custom script configuration"
  end
end

control 'arm-params-02' do
  impact 0.7
  title 'AKS cluster properties version should match expected version'
  desc 'Verify that the AKS cluster Kubernetes version matches the expected version'
  
  tag 'arm'
  tag 'kubernetes-version'
  tag 'cluster-properties'
  tag 'nist-csf: ID.AM-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'kubernetesVersion' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq kubernetes_version }
  end
end

control 'arm-params-03' do
  impact 0.5
  title 'Variable file should exist'
  desc 'Verify that the environment variable file exists for ARM parameter generation'
  
  tag 'arm'
  tag 'files'
  tag 'configuration'
  tag 'infrastructure-as-code'
  tag 'nist-csf: ID.AM-1'
  
  # This would need to be configured with actual file paths
  only_if { input('validate_variable_files', value: false) }
  
  describe "Variable file existence check" do
    skip "Variable file validation requires custom configuration"
  end
end
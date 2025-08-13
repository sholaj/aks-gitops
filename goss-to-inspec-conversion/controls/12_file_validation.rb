# encoding: utf-8
# copyright: DevOps Team

title '12 - File and Configuration Validation'

# Retrieve inputs
arm_template_file = input('arm_template_file', value: nil)
variable_file = input('variable_file', value: nil)
validate_arm_parameters = input('validate_arm_parameters', value: false)
validate_variable_files = input('validate_variable_files', value: false)

control 'file-validation-01' do
  impact 0.5
  title 'ARM template file should exist'
  desc 'Verify that the ARM template file exists and is accessible'
  
  tag 'files'
  tag 'arm-templates'
  tag 'infrastructure'
  tag 'configuration'
  
  only_if { validate_arm_parameters && !arm_template_file.nil? }
  
  describe file(arm_template_file) do
    it { should exist }
    it { should be_file }
    it { should be_readable }
  end
end

control 'file-validation-02' do
  impact 0.5
  title 'Variable file should exist and be valid'
  desc 'Verify that the environment variable file exists and is properly formatted'
  
  tag 'files'
  tag 'variables'
  tag 'configuration'
  tag 'environment'
  
  only_if { validate_variable_files && !variable_file.nil? }
  
  describe file(variable_file) do
    it { should exist }
    it { should be_file }
    it { should be_readable }
  end
end

control 'file-validation-03' do
  impact 0.4
  title 'ARM template should contain valid JSON'
  desc 'Verify that the ARM template file contains valid JSON syntax'
  
  tag 'files'
  tag 'arm-templates'
  tag 'json'
  tag 'syntax'
  tag 'validation'
  
  only_if { validate_arm_parameters && !arm_template_file.nil? && file(arm_template_file).exist? }
  
  describe command("jq empty #{arm_template_file}") do
    its('exit_status') { should eq 0 }
  end
end

control 'file-validation-04' do
  impact 0.4
  title 'Variable file should contain valid YAML'
  desc 'Verify that the variable file contains valid YAML syntax'
  
  tag 'files'
  tag 'variables'
  tag 'yaml'
  tag 'syntax'
  tag 'validation'
  
  only_if { validate_variable_files && !variable_file.nil? && file(variable_file).exist? }
  
  describe command("python -c \"import yaml; yaml.safe_load(open('#{variable_file}'))\"") do
    its('exit_status') { should eq 0 }
  end
end

control 'file-validation-05' do
  impact 0.3
  title 'Required configuration directories should exist'
  desc 'Verify that required configuration directories are present'
  
  tag 'files'
  tag 'directories'
  tag 'structure'
  tag 'organization'
  
  # Common configuration directories that should exist
  required_dirs = [
    '/etc/kubernetes',
    '/var/lib/kubelet'
  ]
  
  required_dirs.each do |dir|
    describe file(dir) do
      it { should exist }
      it { should be_directory }
    end
  end
end

control 'file-validation-06' do
  impact 0.3
  title 'Kubernetes configuration files should have proper permissions'
  desc 'Verify that Kubernetes configuration files have appropriate permissions'
  
  tag 'files'
  tag 'permissions'
  tag 'security'
  tag 'kubernetes'
  tag 'nist-csf: PR.AC-4'
  
  # Only run if we're on a node that has these files
  only_if { file('/etc/kubernetes').exist? }
  
  k8s_config_files = [
    '/etc/kubernetes/kubelet.conf',
    '/etc/kubernetes/bootstrap-kubelet.conf'
  ].select { |f| file(f).exist? }
  
  k8s_config_files.each do |config_file|
    describe file(config_file) do
      it { should be_owned_by 'root' }
      it { should be_grouped_into 'root' }
      its('mode') { should cmp '0600' }
    end
  end
end

control 'file-validation-07' do
  impact 0.2
  title 'System log files should be accessible'
  desc 'Verify that system log files are accessible for monitoring and troubleshooting'
  
  tag 'files'
  tag 'logs'
  tag 'monitoring'
  tag 'troubleshooting'
  tag 'observability'
  
  system_log_files = [
    '/var/log/syslog',
    '/var/log/messages',
    '/var/log/kern.log'
  ].select { |f| file(f).exist? }
  
  # Only check if at least one system log file exists
  only_if { system_log_files.any? }
  
  system_log_files.each do |log_file|
    describe file(log_file) do
      it { should exist }
      it { should be_file }
      it { should be_readable }
    end
  end
end